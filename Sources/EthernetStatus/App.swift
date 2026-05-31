import SwiftUI
import AppKit
import CoreLocation
import ServiceManagement
import Combine

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

// MARK: - Wi-Fi Menu Bar Item Finder

final class WiFiMenuItemFinder {

    /// Click the Wi‑Fi menu item directly via AXPress.
    func clickWiFiDirect() -> Bool {
        guard let wifiItem = findWiFiItem() else { return false }
        return axPress(wifiItem)
    }

    /// Click Wi‑Fi via Control Center popover.
    func clickWiFiViaCC() -> Bool {
        return clickViaControlCenter()
    }

    private func clickViaControlCenter() -> Bool {
        guard let (ccItem, _) = findControlCenterItem() else {
            return false
        }
        guard axPress(ccItem) else { return false }
        let delay = UInt32(UserDefaults.standard.ccClickDelay * 1_000_000)
        usleep(delay)

        if let wifiCheckbox = findWiFiInControlCenter() {
            return axPress(wifiCheckbox)
        }
        return false
    }

    private func findWiFiInControlCenter() -> AXUIElement? {
        guard let ccApp = NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.apple.controlcenter").first else { return nil }
        let app = AXUIElementCreateApplication(ccApp.processIdentifier)

        var windows: CFTypeRef?
        AXUIElementCopyAttributeValue(app, "AXWindows" as CFString, &windows)
        guard let windowList = windows as? [AXUIElement] else { return nil }

        for win in windowList {
            var role: CFTypeRef?
            AXUIElementCopyAttributeValue(win, "AXRole" as CFString, &role)
            guard (role as? String) == "AXWindow" else { continue }
            if let found = findWiFiCheckbox(in: win) { return found }
        }
        return nil
    }

    private func findWiFiCheckbox(in element: AXUIElement) -> AXUIElement? {
        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, "AXChildren" as CFString, &children) == .success,
              let kids = children as? [AXUIElement] else { return nil }

        for kid in kids {
            var role: CFTypeRef?
            AXUIElementCopyAttributeValue(kid, "AXRole" as CFString, &role)
            var desc: CFTypeRef?
            AXUIElementCopyAttributeValue(kid, "AXDescription" as CFString, &desc)
            let descStr = (desc as? String) ?? ""

            // Wi-Fi checkbox: desc like "Wi‑Fi：1203" or "Wi‑Fi：On"
            if (role as? String) == "AXCheckBox", descStr.contains("Wi") && descStr.contains("Fi") {
                return kid
            }

            // Recurse
            if let found = findWiFiCheckbox(in: kid) { return found }
        }
        return nil
    }

    private func findControlCenterItem() -> (AXUIElement, CGPoint)? {
        guard let controlCenter = NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.apple.controlcenter").first else { return nil }
        let app = AXUIElementCreateApplication(controlCenter.processIdentifier)

        var menuBar: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, "AXChildren" as CFString, &menuBar) == .success,
              let barItems = menuBar as? [AXUIElement] else { return nil }

        for child in barItems {
            var role: CFTypeRef?
            AXUIElementCopyAttributeValue(child, "AXRole" as CFString, &role)
            guard (role as? String) == "AXMenuBar" else { continue }
            var items: CFTypeRef?
            guard AXUIElementCopyAttributeValue(child, "AXChildren" as CFString, &items) == .success,
                  let menuItems = items as? [AXUIElement] else { continue }
            for item in menuItems {
                var desc: CFTypeRef?
                AXUIElementCopyAttributeValue(item, "AXDescription" as CFString, &desc)
                if (desc as? String)?.contains("控制中心") == true {
                    var posRef: CFTypeRef?
                    var sizeRef: CFTypeRef?
                    AXUIElementCopyAttributeValue(item, "AXPosition" as CFString, &posRef)
                    AXUIElementCopyAttributeValue(item, "AXSize" as CFString, &sizeRef)
                    var pos = CGPoint.zero, size = CGSize.zero
                    if posRef != nil { AXValueGetValue(posRef as! AXValue, .cgPoint, &pos) }
                    if sizeRef != nil { AXValueGetValue(sizeRef as! AXValue, .cgSize, &size) }
                    return (item, CGPoint(x: pos.x + size.width / 2, y: pos.y + size.height / 2))
                }
            }
        }
        return nil
    }

    private func axPress(_ item: AXUIElement) -> Bool {
        AXUIElementPerformAction(item, kAXPressAction as CFString) == .success
    }

    private func findWiFiItem() -> AXUIElement? {
        guard let controlCenter = NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.apple.controlcenter").first else { return nil }

        let app = AXUIElementCreateApplication(controlCenter.processIdentifier)

        var menuBar: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, "AXChildren" as CFString, &menuBar) == .success,
              let barItems = menuBar as? [AXUIElement] else { return nil }

        for child in barItems {
            var role: CFTypeRef?
            AXUIElementCopyAttributeValue(child, "AXRole" as CFString, &role)
            guard (role as? String) == "AXMenuBar" else { continue }

            var items: CFTypeRef?
            guard AXUIElementCopyAttributeValue(child, "AXChildren" as CFString, &items) == .success,
                  let menuItems = items as? [AXUIElement] else { continue }

            for item in menuItems {
                var desc: CFTypeRef?
                AXUIElementCopyAttributeValue(item, "AXDescription" as CFString, &desc)
                guard ((desc as? String) ?? "").contains("Wi") && ((desc as? String) ?? "").contains("Fi") else { continue }
                return item
            }
        }
        return nil
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let monitor = NetworkObserver()
    private let wifiFinder = WiFiMenuItemFinder()
    private var settingsPopover: NSPopover?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        LocationDelegate.shared.requestPermission()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        updateIcon()
        monitor.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateIcon()
            }.store(in: &cancellables)
        NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateIcon() }
            .store(in: &cancellables)
    }

    private func updateIcon() {
        statusItem.button?.image = iconImage(for: monitor.state)
    }

    private func iconImage(for state: NetworkState) -> NSImage {
        let img: NSImage
        switch state.connectionType {
        case .ethernet:
            let style = UserDefaults.standard.ethernetIconStyle
            let name = style == .appleNative ? "EthernetApple" : "IconTemplate@2x"
            if let url = Bundle.main.url(forResource: name, withExtension: "png"),
               let png = NSImage(contentsOf: url) {
                png.isTemplate = true
                png.size = style == .appleNative
                    ? NSSize(width: 23, height: 13)
                    : NSSize(width: 18, height: 18)
                img = png
            } else {
                img = sfSymbol("network")
            }
        case .wifi:
            if state.isPersonalHotspot {
                img = sfSymbol("personalhotspot")
            } else {
                let name = (state.wifiSignalStrength ?? -100) >= -70 ? "wifi" : "wifi.exclamationmark"
                img = sfSymbol(name)
            }
        case .other:
            img = sfSymbol("wifi.exclamationmark")
        case .none:
            img = state.isWiFiPoweredOn
                ? sfSymbol("wifi.exclamationmark")
                : sfSymbol("wifi.slash")
        }
        return img
    }

    private func sfSymbol(_ name: String) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) ?? NSImage()
        img.isTemplate = true
        return img
    }

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return }
        let action = UserDefaults.standard.clickAction
        let isWiFiClick = (action == .leftOpensWiFi && event.type == .leftMouseUp)
                       || (action == .rightOpensWiFi && event.type == .rightMouseUp)

        if isWiFiClick {
            handleWiFiTrigger()
        } else {
            openSettings()
        }
    }

    private func handleWiFiTrigger() {
        let path = UserDefaults.standard.wifiTriggerPath

        switch path {
        case .systemSettings:
            NSWorkspace.shared.open(
                URL(string: "x-apple.systempreferences:com.apple.preference.network?Wi-Fi")!
            )

        case .menuBarItem:
            guard AXIsProcessTrusted() else {
                openAccessibilityPrefs()
                return
            }
            _ = wifiFinder.clickWiFiDirect()

        case .controlCenter:
            guard AXIsProcessTrusted() else {
                openAccessibilityPrefs()
                return
            }
            _ = wifiFinder.clickWiFiViaCC()
        }
    }

    private func openAccessibilityPrefs() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        )
    }

    @objc private func openSettings() {
        if settingsPopover == nil {
            let popover = NSPopover()
            popover.behavior = .transient
            let settings = SettingsView()
            popover.contentViewController = NSHostingController(rootView: settings)
            settingsPopover = popover
        }
        if let button = statusItem.button {
            settingsPopover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

// MARK: - Settings

struct SettingsView: View {
    @AppStorage("EthernetIconStyle") private var iconStyle: EthernetIconStyle = .classic
    @AppStorage("WiFiTriggerPath") private var triggerPath: WiFiTriggerPath = .controlCenter
    @AppStorage("ClickAction") private var clickAction: ClickAction = .leftOpensWiFi
    @State private var ccDelay: Double = UserDefaults.standard.ccClickDelay

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Ethernet Icon
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color(nsColor: .controlAccentColor))
                        .frame(width: 26, height: 26)
                    if let img = ethernetPreviewImage() {
                        Image(nsImage: img)
                            .foregroundColor(.white)
                    }
                }
                Text("Ethernet Icon")
                    .font(.system(size: 12))
                Spacer()
                Picker("", selection: $iconStyle) {
                    ForEach(EthernetIconStyle.allCases, id: \.self) { s in
                        Text(s.displayName).tag(s)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // Wi-Fi Trigger Path
            VStack(alignment: .leading, spacing: 4) {
                Text("Wi‑Fi Menu Method")
                    .fontWeight(.bold)
                Picker("", selection: $triggerPath) {
                    ForEach(WiFiTriggerPath.allCases, id: \.self) { p in
                        Text(p.displayName).tag(p)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
                Text(triggerDescription)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            if triggerPath == .controlCenter {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Click delay: \(String(format: "%.0f", ccDelay * 1000)) ms")
                        .font(.system(size: 11))
                    Slider(value: $ccDelay, in: 0.0...0.5, step: 0.02) { _ in
                        UserDefaults.standard.ccClickDelay = ccDelay
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Open Wi‑Fi with")
                Picker("", selection: $clickAction) {
                    ForEach(ClickAction.allCases, id: \.self) { a in
                        Text(a.displayName).tag(a)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)


            Divider()

            // Launch at Login
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
                .labelsHidden()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // Quit
            HStack {
                Text("Ethernet Status Lite")
                    .font(.system(size: 10))
                    .foregroundStyle(.quaternary)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
            }
            .padding(12)
        }
        .frame(width: 280)
    }

    private func ethernetPreviewImage() -> NSImage? {
        let name = iconStyle == .appleNative ? "EthernetApple" : "IconTemplate@2x"
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let img = NSImage(contentsOf: url) else { return nil }
        img.isTemplate = true
        img.size = iconStyle == .appleNative
            ? NSSize(width: 18, height: 10)
            : NSSize(width: 17, height: 17)
        return img
    }

    private var triggerDescription: String {
        switch triggerPath {
        case .controlCenter: return "Opens Control Center and clicks the Wi‑Fi section. Works even when the Wi‑Fi icon is hidden."
        case .menuBarItem:   return "Clicks the menu bar Wi‑Fi icon directly. Requires the icon to be visible (may conflict with menu bar managers)."
        case .systemSettings: return "Opens the Wi‑Fi page in System Settings. No accessibility permissions needed."
        }
    }
}

// MARK: - Entry

@main
struct EthernetStatusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene { Settings { EmptyView() } }
}
