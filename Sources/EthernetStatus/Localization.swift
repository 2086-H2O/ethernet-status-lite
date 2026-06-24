import Foundation

// MARK: - Language
/// Add a new language by adding a case to each switch below.

enum AppLanguage: String, CaseIterable {
    case english
    case chinese

    var displayName: String {
        switch self {
        case .english: return "English"
        case .chinese: return "中文"
        }
    }

    /// AX search term for the Control Center menu bar item
    var ccSearchTerm: String {
        switch self {
        case .english: return "Control Center"
        case .chinese: return "控制中心"
        }
    }
}

// MARK: - Localized UI Strings
/// Sections mirror the Settings UI layout from top to bottom.

struct Loc {
    private static var lang: AppLanguage { UserDefaults.standard.appLanguage }

    // MARK: Ethernet Icon section
    /// Section label: "Ethernet Icon" picker row
    static var ethernetIcon: String {
        switch lang {
        case .english: return "Ethernet Icon"
        case .chinese: return "以太网 图标"
        }
    }
    /// Picker option: original author's icon
    static var classicIcon: String {
        switch lang {
        case .english: return "Classic"
        case .chinese: return "经典"
        }
    }
    /// Picker option: Apple official icon
    static var appleIcon: String {
        switch lang {
        case .english: return "Apple"
        case .chinese: return "原生"
        }
    }

    // MARK: Wi‑Fi Menu section
    /// Section label: trigger method radio group
    static var wiFiMenu: String {
        switch lang {
        case .english: return "Wi‑Fi Menu to Launch"
        case .chinese: return "启动的 Wi‑Fi 菜单"
        }
    }
    /// Radio option: open via Control Center
    static var controlCenterTrigger: String {
        switch lang {
        case .english: return "Control Center"
        case .chinese: return "控制中心"
        }
    }
    /// Description text for Control Center mode
    static var ccDesc: String {
        switch lang {
        case .english: return "Simulates clicking Control Center and expanding the Wi‑Fi panel inside. Requires the CC Wi-Fi section existed."
        case .chinese: return "模拟点击控制中心、展开其中 Wi‑Fi 面板。需要控制中心中有 Wi-Fi 区域。"
        }
    }
    /// Radio option: click Wi‑Fi icon directly
    static var menuBarTrigger: String {
        switch lang {
        case .english: return "Menu Bar"
        case .chinese: return "菜单栏"
        }
    }
    /// Description text for Menu Bar mode
    static var menuBarDesc: String {
        switch lang {
        case .english: return "Simulates clicking the native menu bar Wi‑Fi icon directly. Requires the native Wi-Fi icon to be visible. (may conflict with menu bar managers)"
        case .chinese: return "模拟点击菜单栏 Wi‑Fi 图标。需要原生 Wi-Fi 图标可见。（可能与菜单栏管理工具冲突）"
        }
    }
    /// Radio option: open System Settings
    static var settingsTrigger: String {
        switch lang {
        case .english: return "Settings"
        case .chinese: return "系统设置"
        }
    }
    /// Description text for System Settings mode
    static var settingsDesc: String {
        switch lang {
        case .english: return "Opens the Wi‑Fi page in System Settings. No accessibility permissions needed."
        case .chinese: return "打开系统设置中的 Wi‑Fi 页面。无需辅助功能权限。"
        }
    }
    /// CC click delay slider label
    static var clickDelay: String {
        switch lang {
        case .english: return "Click delay"
        case .chinese: return "点击延迟"
        }
    }

    // MARK: Click Action section
    /// Section label: which mouse button triggers Wi‑Fi
    static var openWiFiWith: String {
        switch lang {
        case .english: return "Open Wi-Fi with"
        case .chinese: return "打开 Wi‑Fi 的方式"
        }
    }
    /// Radio option: left-click
    static var leftClick: String {
        switch lang {
        case .english: return "Left-click"
        case .chinese: return "左键单击"
        }
    }
    /// Radio option: right-click
    static var rightClick: String {
        switch lang {
        case .english: return "Right-click"
        case .chinese: return "右键单击"
        }
    }
    /// Radio option: always open Wi-Fi
    static var alwaysWiFi: String {
        switch lang {
        case .english: return "Always open Wi‑Fi"
        case .chinese: return "始终打开 Wi‑Fi"
        }
    }
    /// Radio option: open Network settings on Ethernet
    static var ethernetOpensNetwork: String {
        switch lang {
        case .english: return "Open Network Settings on Ethernet"
        case .chinese: return "接入有线网时，打开网络设置"
        }
    }

    // MARK: Language section
    /// Language picker label
    static var language: String {
        switch lang {
        case .english: return "Language"
        case .chinese: return "语言"
        }
    }
    /// AX custom search terms sub-section label
    static var axSearchTerms: String {
        switch lang {
        case .english: return "AX Search Terms"
        case .chinese: return "AX 搜索词"
        }
    }
    /// AX custom search terms explanation
    static var axSearchDesc: String {
        switch lang {
        case .english: return "The app recognizes Control Center / Menu Bar elements by searching text keywords. Searched words should match your OS language settings. You may customize the searched words if your OS language is not in the language list."
        case .chinese: return "此应用通过文本检索识别控制中心/菜单栏元素。被检索词应当匹配操作系统语言设置。若你的操作系统语言不在语言列表内，请尝试自定义搜索词。"
        }
    }
    /// TextField placeholder: Control Center search keyword
    static var ccSearchField: String {
        switch lang {
        case .english: return "Control Center search name"
        case .chinese: return "控制中心 搜索名"
        }
    }
    /// TextField placeholder: Wi‑Fi search keyword
    static var wifiSearchField: String {
        switch lang {
        case .english: return "Wi‑Fi search name"
        case .chinese: return "Wi‑Fi 搜索名"
        }
    }

    // MARK: Footer
    /// Launch at Login toggle label
    static var launchAtLogin: String {
        switch lang {
        case .english: return "Launch at Login"
        case .chinese: return "登录自启动"
        }
    }
    /// Quit button
    static var quit: String {
        switch lang {
        case .english: return "Quit"
        case .chinese: return "退出"
        }
    }
}

// MARK: - AX Search Terms
///
/// Resolved AX search terms used by WiFiMenuItemFinder.
/// Falls back to language defaults; overridable via UserDefaults.

struct AXSearchTerms {
    /// Search term for finding the Control Center menu bar item
    static var cc: String {
        if let custom = UserDefaults.standard.customCCSearchTerm, !custom.isEmpty { return custom }
        return UserDefaults.standard.appLanguage.ccSearchTerm
    }

    /// Two substrings (both must match) for finding Wi‑Fi elements in AX descriptions
    static var wifi: (String, String) {
        if let custom = UserDefaults.standard.customWiFiSearchTerm, !custom.isEmpty { return (custom, "") }
        return ("Wi", "Fi")
    }
}
