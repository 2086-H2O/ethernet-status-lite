import Foundation
import Network
import CoreWLAN
import CoreLocation
import SystemConfiguration

enum ConnectionType: Equatable {
    case wifi
    case ethernet
    case other
    case none
}

enum EthernetIconStyle: String, CaseIterable {
    case classic        // Original IconTemplate@2x.png
    case appleNative    // Apple Ethernet icon (EthernetApple.png)

    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .appleNative: return "Apple"
        }
    }
}

enum SecurityType: String, Equatable {
    case open = "Open"
    case wep = "WEP"
    case wpa = "WPA"
    case wpa2 = "WPA2"
    case wpa3 = "WPA3"
    case enterprise = "Enterprise"
    case unknown = "Unknown"

    var requiresPassword: Bool {
        self != .open
    }

    init(from network: CWNetwork) {
        if network.supportsSecurity(.wpa3Personal) || network.supportsSecurity(.wpa3Enterprise) {
            self = network.supportsSecurity(.wpa3Enterprise) ? .enterprise : .wpa3
        } else if network.supportsSecurity(.wpa2Personal) || network.supportsSecurity(.wpa2Enterprise) {
            self = network.supportsSecurity(.wpa2Enterprise) ? .enterprise : .wpa2
        } else if network.supportsSecurity(.wpaPersonal) || network.supportsSecurity(.wpaEnterprise) {
            self = network.supportsSecurity(.wpaEnterprise) ? .enterprise : .wpa
        } else if network.supportsSecurity(.dynamicWEP) {
            self = .wep
        } else if network.supportsSecurity(.none) {
            self = .open
        } else {
            self = .unknown
        }
    }
}

enum Band: String, Equatable {
    case twoFour = "2.4 GHz"
    case five = "5 GHz"
    case six = "6 GHz"

    var shortLabel: String {
        switch self {
        case .twoFour: return "2.4"
        case .five: return "5"
        case .six: return "6"
        }
    }

    init(channel: Int) {
        switch channel {
        case 1...14: self = .twoFour
        case 32...177: self = .five
        default: self = .six
        }
    }
}

struct SpeedSample: Equatable {
    let dl: Double
    let ul: Double
}

struct NetworkState: Equatable {
    var connectionType: ConnectionType = .none
    var interfaceName: String?
    var ipAddress: String?
    var wifiSSID: String?
    var wifiSignalStrength: Int?
    var wifiBand: Band?
    var wifiSecurity: SecurityType?
    var ethernetSpeed: String?
    var isWiFiPoweredOn: Bool = false
    var availableNetworks: [WiFiNetwork] = []
    var isScanning: Bool = false
    var speedHistory: [SpeedSample] = []
    var graphScaleMbps: Double = 10
    var downloadMbps: Double = 0
    var uploadMbps: Double = 0
}

struct WiFiNetwork: Identifiable, Equatable, Hashable {
    let id: String
    let ssid: String
    let rssi: Int
    let noise: Int
    let security: SecurityType
    let isConnected: Bool
    let isKnown: Bool
    let channel: Int
    let band: Band

    var signalBars: Double {
        switch rssi {
        case -50...0: return 1.0
        case -60..<(-50): return 0.75
        case -70..<(-60): return 0.55
        case -80..<(-70): return 0.35
        default: return 0.15
        }
    }

    var signalQuality: String {
        switch rssi {
        case -50...0: return "Excellent"
        case -60..<(-50): return "Good"
        case -70..<(-60): return "Fair"
        case -80..<(-70): return "Weak"
        default: return "Very Weak"
        }
    }

    var signalBarsInt: Int {
        switch rssi {
        case -50...0: return 4
        case -60..<(-50): return 3
        case -70..<(-60): return 2
        case -80..<(-70): return 1
        default: return 0
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ssid)
    }

    static func == (lhs: WiFiNetwork, rhs: WiFiNetwork) -> Bool {
        lhs.ssid == rhs.ssid
    }
}

final class NetworkMonitor: ObservableObject {
    @Published var state = NetworkState()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private let scanQueue = DispatchQueue(label: "WiFiScan")
    private var scanTimer: Timer?
    private var trafficTimer: Timer?
    private var lastBytes: (rx: UInt64, tx: UInt64) = (0, 0)
    private var lastBytesTime: Date = .distantPast
    private static let maxSpeedHistory = 60
    private let smoothingAlpha = 0.3

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.handlePathUpdate(path)
        }
        monitor.start(queue: queue)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.startPeriodicScan()
        }

        lastBytes = getNetworkBytes()
        lastBytesTime = Date()
        trafficTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.sampleTraffic()
        }
    }

    deinit {
        monitor.cancel()
        scanTimer?.invalidate()
        trafficTimer?.invalidate()
    }

    private func sampleTraffic() {
        // Also poll RSSI while we're at it
        if state.connectionType == .wifi,
           let iface = CWWiFiClient.shared().interface(),
           iface.powerOn() {
            state.wifiSignalStrength = iface.rssiValue()
        }

        let currentBytes = getNetworkBytes()
        let now = Date()
        let elapsed = now.timeIntervalSince(lastBytesTime)

        guard elapsed > 0 else {
            lastBytes = currentBytes
            lastBytesTime = now
            return
        }

        let dlBytes = currentBytes.rx >= lastBytes.rx ? Double(currentBytes.rx - lastBytes.rx) : 0
        let ulBytes = currentBytes.tx >= lastBytes.tx ? Double(currentBytes.tx - lastBytes.tx) : 0
        let rawDl = (dlBytes * 8) / (elapsed * 1_000_000) // Mbps
        let rawUl = (ulBytes * 8) / (elapsed * 1_000_000)

        // Exponential smoothing
        let dl = state.downloadMbps + smoothingAlpha * (rawDl - state.downloadMbps)
        let ul = state.uploadMbps + smoothingAlpha * (rawUl - state.uploadMbps)

        state.downloadMbps = max(0, dl)
        state.uploadMbps = max(0, ul)

        // Update graph scale — expand fast, shrink slowly
        let instantMax = max(state.downloadMbps, state.uploadMbps, 1)
        if instantMax > state.graphScaleMbps {
            state.graphScaleMbps = instantMax
        } else {
            state.graphScaleMbps = max(1, state.graphScaleMbps * 0.97 + instantMax * 0.03)
        }

        // Append to history
        var history = state.speedHistory
        history.append(SpeedSample(dl: state.downloadMbps, ul: state.uploadMbps))
        if history.count > Self.maxSpeedHistory {
            history.removeFirst(history.count - Self.maxSpeedHistory)
        }
        state.speedHistory = history

        lastBytes = currentBytes
        lastBytesTime = now
    }

    private func getNetworkBytes() -> (rx: UInt64, tx: UInt64) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return (0, 0) }
        defer { freeifaddrs(ifaddr) }

        var totalRx: UInt64 = 0
        var totalTx: UInt64 = 0

        // Read bytes from the active interface
        let targetName = state.interfaceName ?? "en0"

        var ptr = firstAddr
        while true {
            let name = String(cString: ptr.pointee.ifa_name)
            if name == targetName, let data = ptr.pointee.ifa_data {
                let netData = data.assumingMemoryBound(to: if_data.self)
                totalRx += UInt64(netData.pointee.ifi_ibytes)
                totalTx += UInt64(netData.pointee.ifi_obytes)
            }
            guard let next = ptr.pointee.ifa_next else { break }
            ptr = next
        }

        return (totalRx, totalTx)
    }

    private func startPeriodicScan() {
        scanTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.scanNetworks()
        }
        scanNetworks()
    }

    // MARK: - Wi-Fi Control

    func toggleWiFi() {
        guard let iface = CWWiFiClient.shared().interface() else { return }
        let newState = !iface.powerOn()
        try? iface.setPower(newState)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.refreshState()
            if newState { self?.scanNetworks() }
        }
    }

    func scanNetworks() {
        guard !state.isScanning else { return }
        DispatchQueue.main.async { self.state.isScanning = true }

        scanQueue.async { [weak self] in
            guard let self else { return }
            let networks = self.buildNetworkList()
            DispatchQueue.main.async {
                self.state.availableNetworks = networks
                self.state.isScanning = false
            }
        }
    }

    func connect(to network: WiFiNetwork) {
        scanQueue.async {
            guard let iface = CWWiFiClient.shared().interface() else { return }
            guard let results = try? iface.scanForNetworks(withName: network.ssid) else { return }
            guard let target = results.first else { return }
            try? iface.associate(to: target, password: nil)
        }
    }

    func disconnect() {
        CWWiFiClient.shared().interface()?.disassociate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refreshState()
        }
    }

    // MARK: - Network Scanning

    private func buildNetworkList() -> [WiFiNetwork] {
        guard let iface = CWWiFiClient.shared().interface(), iface.powerOn() else {
            return []
        }

        let currentSSID = iface.ssid()

        let knownSSIDs: Set<String> = {
            guard let config = iface.configuration() else { return [] }
            let profiles = config.networkProfiles.array as? [CWNetworkProfile] ?? []
            return Set(profiles.compactMap { $0.ssid })
        }()

        // Always attempt a fresh scan; fall back to cached results on failure
        let scanned = try? iface.scanForNetworks(withSSID: nil)
        let results: Set<CWNetwork>
        if let scanned, !scanned.isEmpty {
            results = scanned
        } else {
            results = iface.cachedScanResults() ?? []
        }

        var best: [String: CWNetwork] = [:]
        for net in results {
            guard let ssid = net.ssid, !ssid.isEmpty else { continue }
            if let existing = best[ssid] {
                if net.rssiValue > existing.rssiValue {
                    best[ssid] = net
                }
            } else {
                best[ssid] = net
            }
        }

        return best.values.map { net in
            let ssid = net.ssid ?? ""
            let channel = net.wlanChannel?.channelNumber ?? 0
            return WiFiNetwork(
                id: net.bssid ?? UUID().uuidString,
                ssid: ssid,
                rssi: net.rssiValue,
                noise: net.noiseMeasurement,
                security: SecurityType(from: net),
                isConnected: ssid == currentSSID,
                isKnown: knownSSIDs.contains(ssid),
                channel: channel,
                band: Band(channel: channel)
            )
        }
        .sorted { a, b in
            if a.isConnected != b.isConnected { return a.isConnected }
            if a.isKnown != b.isKnown { return a.isKnown }
            return a.rssi > b.rssi
        }
    }

    // MARK: - Path Monitoring

    private func refreshState() {
        let path = monitor.currentPath
        handlePathUpdate(path)
    }

    private func handlePathUpdate(_ path: NWPath) {
        let iface = CWWiFiClient.shared().interface()
        let wifiPowered = iface?.powerOn() ?? false

        var newState = NetworkState()
        newState.isWiFiPoweredOn = wifiPowered

        if path.status != .satisfied {
            newState.connectionType = .none
        } else if path.usesInterfaceType(.wiredEthernet) {
            let ifName = activeInterfaceName(for: .wiredEthernet, path: path)
            newState.connectionType = .ethernet
            newState.interfaceName = ifName
            newState.ipAddress = ipAddress(for: ifName)
            newState.ethernetSpeed = ethernetMediaSpeed(for: ifName)
        } else if path.usesInterfaceType(.wifi) {
            let ifName = activeInterfaceName(for: .wifi, path: path)
            newState.connectionType = .wifi
            newState.interfaceName = ifName
            newState.ipAddress = ipAddress(for: ifName)
            newState.wifiSSID = iface?.ssid()
            newState.wifiSignalStrength = iface?.rssiValue()
            if let ch = iface?.wlanChannel()?.channelNumber {
                newState.wifiBand = Band(channel: ch)
            }
            // Detect current network security from scan results
            if let ssid = newState.wifiSSID,
               let cached = iface?.cachedScanResults(),
               let net = cached.first(where: { $0.ssid == ssid }) {
                newState.wifiSecurity = SecurityType(from: net)
            }
        } else {
            newState.connectionType = .other
            newState.interfaceName = path.availableInterfaces.first?.name
            newState.ipAddress = ipAddress(for: newState.interfaceName)
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            newState.availableNetworks = self.state.availableNetworks
            newState.isScanning = self.state.isScanning
            self.state = newState
        }
    }

    // MARK: - Helpers

    private func activeInterfaceName(for type: NWInterface.InterfaceType, path: NWPath) -> String? {
        path.availableInterfaces.first { $0.type == type }?.name
    }

    private func ipAddress(for interfaceName: String?) -> String? {
        guard let name = interfaceName else { return nil }
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let family = interface.ifa_addr.pointee.sa_family
            guard family == UInt8(AF_INET) else { continue }
            let ifName = String(cString: interface.ifa_name)
            guard ifName == name else { continue }
            var addr = interface.ifa_addr.pointee
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(
                &addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                &hostname, socklen_t(hostname.count),
                nil, 0, NI_NUMERICHOST
            )
            return String(cString: hostname)
        }
        return nil
    }

    private func ethernetMediaSpeed(for interfaceName: String?) -> String? {
        guard let name = interfaceName else { return nil }
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/ifconfig")
        process.arguments = [name]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return nil }

        guard let mediaLine = output.components(separatedBy: "\n").first(where: { $0.contains("media:") }) else {
            return nil
        }

        if let openParen = mediaLine.firstIndex(of: "("),
           let closeParen = mediaLine.firstIndex(of: ")") {
            return String(mediaLine[mediaLine.index(after: openParen)..<closeParen])
        }

        return mediaLine.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "media: ", with: "")
    }
}

// MARK: - Preferences

extension UserDefaults {
    private static let ethernetIconKey = "EthernetIconStyle"

    var ethernetIconStyle: EthernetIconStyle {
        get {
            guard let raw = string(forKey: Self.ethernetIconKey),
                  let style = EthernetIconStyle(rawValue: raw) else {
                return .classic
            }
            return style
        }
        set { set(newValue.rawValue, forKey: Self.ethernetIconKey) }
    }

}
