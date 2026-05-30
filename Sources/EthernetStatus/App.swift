import SwiftUI
import AppKit
import CoreLocation
import ServiceManagement

// MARK: - Location Permission

final class LocationDelegate: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationDelegate()
    private let manager = CLLocationManager()
    @Published var isAuthorized = false

    override init() {
        super.init()
        manager.delegate = self
        updateStatus()
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async { self.updateStatus() }
    }

    private func updateStatus() {
        let authorized: Bool
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: authorized = true
        default: authorized = false
        }
        if isAuthorized != authorized { isAuthorized = authorized }
    }
}

// MARK: - App

@main
struct EthernetStatusApp: App {
    @StateObject private var monitor = NetworkMonitor()

    init() {
        LocationDelegate.shared.requestPermission()
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverContent(monitor: monitor)
                .frame(width: 300)
                .onAppear { monitor.scanNetworks() }
        } label: {
            MenuBarIcon(state: monitor.state)
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Menu Bar Icon

struct MenuBarIcon: View {
    let state: NetworkState

    var body: some View {
        switch state.connectionType {
        case .ethernet:
            let style = UserDefaults.standard.ethernetIconStyle
            switch style {
            case .appleNative:
                if let img = appleEthernetImage() {
                    Image(nsImage: img)
                } else if let img = ethernetImage() {
                    Image(nsImage: img)
                } else {
                    Image(nsImage: sfSymbol("network"))
                }
            case .classic:
                if let img = ethernetImage() {
                    Image(nsImage: img)
                } else {
                    Image(nsImage: sfSymbol("network"))
                }
            }
        case .wifi:
            Image(nsImage: sfSymbol(wifiIconName(rssi: state.wifiSignalStrength)))
        case .other:
            Image(nsImage: sfSymbol("network"))
        case .none:
            Image(nsImage: sfSymbol("wifi.slash"))
        }
    }

    private func sfSymbol(_ name: String) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) ?? NSImage()
        img.isTemplate = true
        return img
    }

    private func ethernetImage() -> NSImage? {
        guard let url = Bundle.main.url(forResource: "IconTemplate@2x", withExtension: "png"),
              let img = NSImage(contentsOf: url) else { return nil }
        img.isTemplate = true
        img.size = NSSize(width: 18, height: 18)
        return img
    }

    private func appleEthernetImage() -> NSImage? {
        guard let url = Bundle.main.url(forResource: "EthernetApple", withExtension: "png"),
              let img = NSImage(contentsOf: url) else { return nil }
        img.isTemplate = true
        img.size = NSSize(width: 23, height: 13)
        return img
    }

    private func wifiIconName(rssi: Int?) -> String {
        guard let rssi else { return "wifi" }
        switch rssi {
        case -70...0: return "wifi"
        default: return "wifi.exclamationmark"
        }
    }
}

// MARK: - Popover Content

struct PopoverContent: View {
    @ObservedObject var monitor: NetworkMonitor
    @ObservedObject private var location = LocationDelegate.shared
    @State private var showSettings = false

    var body: some View {
        Group {
            if showSettings {
                SettingsView(onBack: { showSettings = false })
                    .transition(.move(edge: .trailing))
            } else {
                mainView
                    .transition(.move(edge: .leading))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showSettings)
        .onDisappear { showSettings = false }
    }

    private var mainView: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.4).padding(.horizontal, 8)

            if !monitor.state.isWiFiPoweredOn && monitor.state.connectionType != .ethernet {
                wifiOffView
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        connectionCard
                        Divider().opacity(0.4).padding(.horizontal, 8).padding(.vertical, 4)
                        networksList
                    }
                }
            }

            Divider().opacity(0.4).padding(.horizontal, 8)
            footer
        }
    }

    // MARK: - Header

    private var connectionName: String {
        switch monitor.state.connectionType {
        case .wifi: return monitor.state.wifiSSID ?? "Wi-Fi"
        case .ethernet: return "Ethernet"
        case .other: return "Network"
        case .none: return "Wi-Fi"
        }
    }

    private var header: some View {
        HStack {
            Text("Wi-Fi")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            if monitor.state.isScanning {
                ProgressView()
                    .controlSize(.mini)
                    .scaleEffect(0.7)
            }
            Toggle("", isOn: Binding(
                get: { monitor.state.isWiFiPoweredOn },
                set: { _ in monitor.toggleWiFi() }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
            .scaleEffect(1.15)
            .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    // MARK: - Wi-Fi Off

    private var wifiOffView: some View {
        VStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("Wi-Fi is off")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    // MARK: - Connection Card

    private func ethernetBadgeImage() -> NSImage? {
        let style = UserDefaults.standard.ethernetIconStyle
        let name = style == .appleNative ? "EthernetApple" : "IconTemplate@2x"
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let img = NSImage(contentsOf: url) else { return nil }
        img.isTemplate = true
        img.size = style == .appleNative
            ? NSSize(width: 19, height: 11)
            : NSSize(width: 14, height: 14)
        return img
    }

    @ViewBuilder
    private var badgeImage: some View {
        if monitor.state.connectionType == .ethernet,
           let img = ethernetBadgeImage() {
            Image(nsImage: img)
        } else {
            Image(systemName: badgeSymbolName)
                .font(.system(size: 13, weight: .semibold))
        }
    }

    private var badgeSymbolName: String {
        switch monitor.state.connectionType {
        case .wifi: return "wifi"
        case .other: return "network"
        default: return "wifi.slash"
        }
    }

    @ViewBuilder
    private var connectionCard: some View {
        let isConnected = monitor.state.connectionType == .wifi || monitor.state.connectionType == .ethernet
        if isConnected {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    // Badge — tap to disconnect (wifi only)
                    Button {
                        if monitor.state.connectionType == .wifi { monitor.disconnect() }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(nsColor: .controlAccentColor))
                                .frame(width: 28, height: 28)
                            badgeImage
                        }
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .help(monitor.state.connectionType == .wifi ? "Disconnect" : "")

                    // Connection details
                    VStack(alignment: .leading, spacing: 1) {
                        Text(connectionName)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                        connectionSubtitle
                    }

                    Spacer()

                    // Current speed values
                    VStack(alignment: .trailing, spacing: 2) {
                        SpeedLabel(value: monitor.state.downloadMbps, arrow: "arrow.down", color: .blue)
                        SpeedLabel(value: monitor.state.uploadMbps, arrow: "arrow.up", color: .green)
                    }
                }

                // Speed graph
                SpeedGraph(history: monitor.state.speedHistory, scaleMbps: monitor.state.graphScaleMbps)
                    .frame(height: 48)
                    .padding(.top, 6)

                // Bottom row: IP + extra info
                if let ip = monitor.state.ipAddress {
                    HStack {
                        Text("IP")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.tertiary)
                        Text(ip)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        connectionTrailingInfo
                    }
                    .padding(.top, 4)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private var connectionSubtitle: some View {
        switch monitor.state.connectionType {
        case .wifi:
            HStack(spacing: 4) {
                if let band = monitor.state.wifiBand {
                    Text(band.rawValue)
                }
                if let sec = monitor.state.wifiSecurity {
                    Text("\u{00B7}")
                    Text(sec.rawValue)
                }
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
        case .ethernet:
            if let speed = monitor.state.ethernetSpeed {
                Text(speed)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var connectionTrailingInfo: some View {
        switch monitor.state.connectionType {
        case .wifi:
            if let rssi = monitor.state.wifiSignalStrength {
                Text("\(rssi) dBm")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        case .ethernet:
            if let iface = monitor.state.interfaceName {
                Text(iface)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        default:
            EmptyView()
        }
    }

    // MARK: - Networks List

    private var knownNetworks: [WiFiNetwork] {
        monitor.state.availableNetworks.filter { !$0.isConnected && $0.isKnown }
    }

    private var otherNetworks: [WiFiNetwork] {
        monitor.state.availableNetworks.filter { !$0.isConnected && !$0.isKnown }
    }

    @ViewBuilder
    private var networksList: some View {
        VStack(spacing: 0) {
            if !location.isAuthorized {
                locationPermissionBanner
            }

            if !knownNetworks.isEmpty {
                sectionHeader("Known Networks")
                ForEach(knownNetworks) { network in
                    NetworkRow(network: network) {
                        monitor.connect(to: network)
                    }
                }
            }

            if !otherNetworks.isEmpty {
                sectionHeader("Other Networks")
                ForEach(Array(otherNetworks.prefix(15))) { network in
                    NetworkRow(network: network) {
                        monitor.connect(to: network)
                    }
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }

    private var locationPermissionBanner: some View {
        VStack(spacing: 6) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
            Text("Location access is needed to see nearby networks and Wi-Fi names.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                NSWorkspace.shared.open(
                    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")!
                )
            }
            .font(.system(size: 11))
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button { showSettings = true } label: {
                Image(systemName: "gear")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                .font(.system(size: 10))
                .foregroundStyle(.quaternary)

            Spacer()

            Button("Wi-Fi Settings...") {
                NSWorkspace.shared.open(
                    URL(string: "x-apple.systempreferences:com.apple.Network-Settings.extension")!
                )
            }
            .font(.system(size: 11))
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Settings View

struct SettingsView: View {
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Back button
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 12))
                }
                .foregroundStyle(.secondary)
                .padding(6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 4)

            // Settings
            VStack(spacing: 0) {
                HStack {
                    Text("Launch at Login")
                        .font(.system(size: 12))
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { SMAppService.mainApp.status == .enabled },
                        set: { enabled in
                            try? enabled ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                        }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .scaleEffect(1.15)
                    .labelsHidden()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }

            Divider().opacity(0.2).padding(.horizontal, 8)

            VStack(spacing: 0) {
                HStack {
                    Text("Ethernet Icon")
                        .font(.system(size: 12))
                    Spacer()
                    Picker("", selection: Binding(
                        get: { UserDefaults.standard.ethernetIconStyle },
                        set: { UserDefaults.standard.ethernetIconStyle = $0 }
                    )) {
                        ForEach(EthernetIconStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 130)
                    .labelsHidden()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }

            Spacer()

            // Footer
            Divider().opacity(0.4).padding(.horizontal, 8)
            HStack {
                Text("Ethernet Status v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                    .font(.system(size: 10))
                    .foregroundStyle(.quaternary)
                Spacer()
                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .font(.system(size: 11))
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Speed Label

struct SpeedLabel: View {
    let value: Double
    let arrow: String
    let color: Color

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: arrow)
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(color)
            Text(formatSpeed(value))
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private func formatSpeed(_ mbps: Double) -> String {
        if mbps >= 100 {
            return String(format: "%.0f Mb", mbps)
        } else if mbps >= 10 {
            return String(format: "%.1f Mb", mbps)
        } else if mbps >= 1 {
            return String(format: "%.1f Mb", mbps)
        } else if mbps >= 0.01 {
            return String(format: "%.0f Kb", mbps * 1000)
        } else {
            return "0 Kb"
        }
    }
}

// MARK: - Speed Graph

struct SpeedGraph: View {
    let history: [SpeedSample]
    let scaleMbps: Double

    var body: some View {
        Canvas { context, size in
            guard history.count >= 2 else { return }

            let w = size.width
            let h = size.height
            let maxSpeed = max(scaleMbps, 1)
            let stepX = w / CGFloat(max(history.count - 1, 1))

            let dlPoints = history.enumerated().map { i, sample in
                CGPoint(
                    x: CGFloat(i) * stepX,
                    y: h * 0.05 + (h * 0.9) * (1 - CGFloat(sample.dl / maxSpeed))
                )
            }
            let ulPoints = history.enumerated().map { i, sample in
                CGPoint(
                    x: CGFloat(i) * stepX,
                    y: h * 0.05 + (h * 0.9) * (1 - CGFloat(sample.ul / maxSpeed))
                )
            }

            let dlLine = smoothPath(through: dlPoints)
            let ulLine = smoothPath(through: ulPoints)

            // Gradient fill under download curve
            var dlFill = dlLine
            dlFill.addLine(to: CGPoint(x: dlPoints.last!.x, y: h))
            dlFill.addLine(to: CGPoint(x: dlPoints[0].x, y: h))
            dlFill.closeSubpath()

            context.fill(dlFill, with: .linearGradient(
                Gradient(stops: [
                    .init(color: .blue.opacity(0.25), location: 0),
                    .init(color: .blue.opacity(0.08), location: 0.5),
                    .init(color: .blue.opacity(0.0), location: 1.0),
                ]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: h)
            ))

            // Download line
            context.stroke(dlLine, with: .color(.blue), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            // Upload line
            context.stroke(ulLine, with: .color(.green), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    /// Catmull-Rom to cubic Bezier smooth path
    private func smoothPath(through points: [CGPoint]) -> Path {
        guard points.count >= 2 else { return Path() }
        var path = Path()
        path.move(to: points[0])

        for i in 0..<points.count - 1 {
            let p0 = i > 0 ? points[i - 1] : points[0]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = i + 2 < points.count ? points[i + 2] : points[i + 1]

            let factor: CGFloat = 1.0 / 6.0
            let cp1 = CGPoint(
                x: p1.x + (p2.x - p0.x) * factor,
                y: p1.y + (p2.y - p0.y) * factor
            )
            let cp2 = CGPoint(
                x: p2.x - (p3.x - p1.x) * factor,
                y: p2.y - (p3.y - p1.y) * factor
            )
            path.addCurve(to: p2, control1: cp1, control2: cp2)
        }

        return path
    }
}

// MARK: - Network Row

struct NetworkRow: View {
    let network: WiFiNetwork
    let onConnect: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onConnect) {
            HStack(spacing: 6) {
                // Wi-Fi signal icon with variable fill
                Image(systemName: "wifi", variableValue: network.signalBars)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(signalColor)
                    .frame(width: 20, height: 20)

                // SSID
                Text(network.ssid)
                    .font(.system(size: 12))
                    .lineLimit(1)

                Spacer()

                // Right side info
                HStack(spacing: 5) {
                    // RSSI
                    Text("\(network.rssi)")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)

                    // Band badge (only for 5/6 GHz)
                    if network.band != .twoFour {
                        Text(network.band.shortLabel)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.primary.opacity(0.06))
                            )
                    }

                    // Lock icon
                    if network.security.requiresPassword {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isHovering ? Color.primary.opacity(0.06) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .help("\(network.signalQuality) signal (\(network.rssi) dBm)")
    }

    private var signalColor: Color {
        switch network.signalBarsInt {
        case 4: return .primary
        case 3: return .primary.opacity(0.85)
        case 2: return .secondary
        case 1: return .orange.opacity(0.85)
        default: return .red.opacity(0.75)
        }
    }
}
