import Foundation
import ProcessManagerCore

enum AppLanguage: String {
    case zhHans
    case english
}

enum L10nKey: Hashable {
    case appName
    case portMonitoring
    case activeRecognition
    case pauseMonitoring
    case resumeMonitoring
    case scan
    case settings
    case quit
    case noEnabledPorts
    case monitoringPaused
    case noRuleMatches
    case idle
    case idlePorts
    case expandIdlePorts
    case collapseIdlePorts
    case sendTerm
    case forceKill
    case waitingForExit
    case stopContainer
    case killContainer
    case dockerProxyProtected
    case systemProcessProtected
    case systemProcessBadge
    case systemProcessRevealHelp
    case noPublishedPorts
    case terminateProcess
    case ready
    case scanning
    case noTargetProcesses
    case portsTab
    case processesTab
    case generalTab
    case add
    case portPlaceholder
    case labelPlaceholder
    case delete
    case activeRules
    case keywordRegexPlaceholder
    case enableMonitoring
    case scanInterval
    case scanNow
    case resetDefaults
    case termHint
    case permissionHint
    case language
    case appearance
    case back
    case save
    case followSystem
    case chinese
    case english
    case light
    case dark
}

enum L10n {
    static func language(for mode: LanguageMode) -> AppLanguage {
        switch mode {
        case .system:
            let preferred = Locale.preferredLanguages.first?.lowercased() ?? ""
            return preferred.hasPrefix("zh") ? .zhHans : .english
        case .zhHans:
            return .zhHans
        case .english:
            return .english
        }
    }

    static func text(_ key: L10nKey, language: AppLanguage) -> String {
        switch language {
        case .zhHans:
            zhHans[key] ?? english[key] ?? ""
        case .english:
            english[key] ?? zhHans[key] ?? ""
        }
    }

    static func processCount(_ count: Int, language: AppLanguage) -> String {
        switch language {
        case .zhHans:
            "\(count) 个进程"
        case .english:
            count == 1 ? "1 process" : "\(count) processes"
        }
    }

    static func foundProcessCount(_ count: Int, language: AppLanguage) -> String {
        switch language {
        case .zhHans:
            "发现 \(count) 个进程"
        case .english:
            count == 1 ? "Found 1 process" : "Found \(count) processes"
        }
    }

    static func terminated(target: String, force: Bool, language: AppLanguage) -> String {
        switch language {
        case .zhHans:
            force ? "已强制终止 \(target)" : "已发送终止信号 \(target)"
        case .english:
            force ? "Force killed \(target)" : "Sent terminate signal to \(target)"
        }
    }

    static func terminateFailed(target: String, error: String, language: AppLanguage) -> String {
        switch language {
        case .zhHans:
            "无法终止 \(target)：\(error)"
        case .english:
            "Could not terminate \(target): \(error)"
        }
    }

    private static let zhHans: [L10nKey: String] = [
        .appName: "DevMinder",
        .portMonitoring: "端口监听",
        .activeRecognition: "主动识别",
        .pauseMonitoring: "暂停监测",
        .resumeMonitoring: "恢复监测",
        .scan: "扫描",
        .settings: "设置",
        .quit: "退出",
        .noEnabledPorts: "未启用端口",
        .monitoringPaused: "监测已暂停",
        .noRuleMatches: "没有命中规则",
        .idle: "空闲",
        .idlePorts: "空闲端口",
        .expandIdlePorts: "点击展开空闲端口",
        .collapseIdlePorts: "点击收起空闲端口",
        .sendTerm: "发送 TERM",
        .forceKill: "强制 KILL",
        .waitingForExit: "等待退出",
        .stopContainer: "停止容器",
        .killContainer: "强制停止容器",
        .dockerProxyProtected: "这是 Docker Desktop 端口代理，不能直接终止。",
        .systemProcessProtected: "这是 Apple 系统进程，不能直接终止。",
        .systemProcessBadge: "系统",
        .systemProcessRevealHelp: "可能是误判，点击显示停止按钮。",
        .noPublishedPorts: "未暴露端口",
        .terminateProcess: "终止进程",
        .ready: "准备就绪",
        .scanning: "扫描中",
        .noTargetProcesses: "未发现目标进程",
        .portsTab: "端口",
        .processesTab: "进程",
        .generalTab: "通用",
        .add: "添加",
        .portPlaceholder: "端口",
        .labelPlaceholder: "标签",
        .delete: "删除",
        .activeRules: "主动识别规则",
        .keywordRegexPlaceholder: "关键词或 /正则/",
        .enableMonitoring: "启用监测",
        .scanInterval: "扫描间隔",
        .scanNow: "立即扫描",
        .resetDefaults: "恢复默认",
        .termHint: "TERM 会让进程自行退出；KILL 用于进程不响应时。",
        .permissionHint: "只能终止当前用户有权限操作的进程；Docker 映射端口会停止容器，不会终止 Docker Desktop。",
        .language: "语言",
        .appearance: "外观",
        .back: "返回",
        .save: "保存",
        .followSystem: "跟随系统",
        .chinese: "中文",
        .english: "English",
        .light: "浅色",
        .dark: "深色"
    ]

    private static let english: [L10nKey: String] = [
        .appName: "DevMinder",
        .portMonitoring: "Port Watch",
        .activeRecognition: "Process Rules",
        .pauseMonitoring: "Pause monitoring",
        .resumeMonitoring: "Resume monitoring",
        .scan: "Scan",
        .settings: "Settings",
        .quit: "Quit",
        .noEnabledPorts: "No enabled ports",
        .monitoringPaused: "Monitoring is paused",
        .noRuleMatches: "No rule matches",
        .idle: "Idle",
        .idlePorts: "Idle ports",
        .expandIdlePorts: "Click to show idle ports",
        .collapseIdlePorts: "Click to hide idle ports",
        .sendTerm: "Send TERM",
        .forceKill: "Force KILL",
        .waitingForExit: "Waiting for exit",
        .stopContainer: "Stop container",
        .killContainer: "Kill container",
        .dockerProxyProtected: "This is a Docker Desktop port proxy and cannot be terminated directly.",
        .systemProcessProtected: "This is an Apple system process and cannot be terminated directly.",
        .systemProcessBadge: "System",
        .systemProcessRevealHelp: "This may be a false positive. Click to show the stop button.",
        .noPublishedPorts: "No published ports",
        .terminateProcess: "Terminate process",
        .ready: "Ready",
        .scanning: "Scanning",
        .noTargetProcesses: "No target processes found",
        .portsTab: "Ports",
        .processesTab: "Processes",
        .generalTab: "General",
        .add: "Add",
        .portPlaceholder: "Port",
        .labelPlaceholder: "Label",
        .delete: "Delete",
        .activeRules: "Process Rules",
        .keywordRegexPlaceholder: "Keyword or /regex/",
        .enableMonitoring: "Enable monitoring",
        .scanInterval: "Scan interval",
        .scanNow: "Scan now",
        .resetDefaults: "Reset defaults",
        .termHint: "TERM lets a process exit cleanly; use KILL when it does not respond.",
        .permissionHint: "Only processes your current user can control may be terminated; Docker port mappings stop the container, not Docker Desktop.",
        .language: "Language",
        .appearance: "Appearance",
        .back: "Back",
        .save: "Save",
        .followSystem: "Follow System",
        .chinese: "中文",
        .english: "English",
        .light: "Light",
        .dark: "Dark"
    ]
}

extension LanguageMode {
    func localizedName(language: AppLanguage) -> String {
        switch self {
        case .system:
            L10n.text(.followSystem, language: language)
        case .zhHans:
            L10n.text(.chinese, language: language)
        case .english:
            L10n.text(.english, language: language)
        }
    }
}

extension AppearanceMode {
    func localizedName(language: AppLanguage) -> String {
        switch self {
        case .system:
            L10n.text(.followSystem, language: language)
        case .light:
            L10n.text(.light, language: language)
        case .dark:
            L10n.text(.dark, language: language)
        }
    }
}
