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
    case classic
    case appleNative

    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .appleNative: return "Apple"
        }
    }
}

enum WiFiTriggerPath: String, CaseIterable {
    case controlCenter
    case menuBarItem
    case systemSettings

    var displayName: String {
        switch self {
        case .controlCenter: return "Control Center"
        case .menuBarItem: return "Menu Bar"
        case .systemSettings: return "Settings"
        }
    }
}

enum ClickAction: String, CaseIterable {
    case leftOpensWiFi
    case rightOpensWiFi

    var displayName: String {
        switch self {
        case .leftOpensWiFi: return "Left-click"
        case .rightOpensWiFi: return "Right-click"
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
    var isPersonalHotspot: Bool = false
}

final class NetworkObserver: ObservableObject {
    @Published var state = NetworkState()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkObserver")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.handlePathUpdate(path)
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    // MARK: - Path Monitoring

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
        } else if !wifiPowered {
            newState.connectionType = .none
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
            // Detect security type and hotspot from current network
            if let ssid = newState.wifiSSID,
               let cached = iface?.cachedScanResults(),
               let net = cached.first(where: { $0.ssid == ssid }) {
                newState.wifiSecurity = SecurityType(from: net)
                newState.isPersonalHotspot = net.value(forKey: "isPersonalHotspot") as? Bool ?? false
            }
            if !newState.isPersonalHotspot {
                newState.isPersonalHotspot = path.isExpensive
            }
        } else {
            newState.connectionType = .other
            newState.interfaceName = path.availableInterfaces.first?.name
            newState.ipAddress = ipAddress(for: newState.interfaceName)
        }

        DispatchQueue.main.async { [weak self] in
            self?.state = newState
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
    private static let wifiTriggerKey = "WiFiTriggerPath"
    private static let ccDelayKey = "CCClickDelay"
    private static let clickActionKey = "ClickAction"

    var ethernetIconStyle: EthernetIconStyle {
        get {
            guard let raw = string(forKey: Self.ethernetIconKey),
                  let style = EthernetIconStyle(rawValue: raw) else { return .classic }
            return style
        }
        set { set(newValue.rawValue, forKey: Self.ethernetIconKey) }
    }

    var wifiTriggerPath: WiFiTriggerPath {
        get {
            guard let raw = string(forKey: Self.wifiTriggerKey),
                  let path = WiFiTriggerPath(rawValue: raw) else { return .controlCenter }
            return path
        }
        set { set(newValue.rawValue, forKey: Self.wifiTriggerKey) }
    }

    var ccClickDelay: Double {
        get {
            let v = double(forKey: Self.ccDelayKey)
            return v > 0 ? v : 0.3
        }
        set { set(newValue, forKey: Self.ccDelayKey) }
    }

    var clickAction: ClickAction {
        get {
            guard let raw = string(forKey: Self.clickActionKey),
                  let action = ClickAction(rawValue: raw) else { return .leftOpensWiFi }
            return action
        }
        set { set(newValue.rawValue, forKey: Self.clickActionKey) }
    }
}
