import Foundation

public struct PortWatch: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var port: Int
    public var label: String
    public var enabled: Bool

    public init(id: UUID = UUID(), port: Int, label: String = "", enabled: Bool = true) {
        self.id = id
        self.port = port
        self.label = label
        self.enabled = enabled
    }

    public var displayName: String {
        label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? ":\(port)" : label
    }
}

public struct ProcessRule: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var pattern: String
    public var label: String
    public var enabled: Bool

    public init(id: UUID = UUID(), pattern: String, label: String = "", enabled: Bool = true) {
        self.id = id
        self.pattern = pattern
        self.label = label
        self.enabled = enabled
    }

    public var displayName: String {
        label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? pattern : label
    }
}

public enum ProcessTerminationTarget: Equatable, Hashable, Sendable {
    case process(pid: Int)
    case dockerContainer(id: String, name: String)
    case protectedDockerHost(pid: Int)
    case protectedSystemProcess(pid: Int, name: String)
    case systemProcessOverride(pid: Int, name: String)

    public var id: String {
        switch self {
        case .process(let pid):
            return "pid-\(pid)"
        case .dockerContainer(let id, _):
            return "docker-\(id)"
        case .protectedDockerHost(let pid):
            return "docker-host-\(pid)"
        case .protectedSystemProcess(let pid, _), .systemProcessOverride(let pid, _):
            return "system-\(pid)"
        }
    }

    public var displayLabel: String {
        switch self {
        case .process(let pid):
            return "pid \(pid)"
        case .dockerContainer(let id, let name):
            let shortID = String(id.prefix(12))
            return name.isEmpty ? "docker \(shortID)" : "docker \(name)"
        case .protectedDockerHost(let pid):
            return "docker proxy pid \(pid)"
        case .protectedSystemProcess(let pid, let name), .systemProcessOverride(let pid, let name):
            return name.isEmpty ? "system pid \(pid)" : "\(name) pid \(pid)"
        }
    }

    public var canTerminate: Bool {
        switch self {
        case .protectedDockerHost, .protectedSystemProcess:
            return false
        case .process, .dockerContainer, .systemProcessOverride:
            return true
        }
    }

    public var isDockerContainer: Bool {
        if case .dockerContainer = self {
            return true
        }

        return false
    }

    public var isProtectedSystemProcess: Bool {
        if case .protectedSystemProcess = self {
            return true
        }

        return false
    }

    public var systemOverrideTarget: ProcessTerminationTarget? {
        if case .protectedSystemProcess(let pid, let name) = self {
            return .systemProcessOverride(pid: pid, name: name)
        }

        return nil
    }

    public var isPlainProcess: Bool {
        if case .process = self {
            return true
        }

        return false
    }
}

public struct DockerPublishedContainer: Equatable, Hashable, Identifiable, Sendable {
    public var id: String { containerID }

    public let containerID: String
    public let name: String
    public let image: String
    public let status: String
    public let ports: String

    public init(
        containerID: String,
        name: String,
        image: String = "",
        status: String = "",
        ports: String
    ) {
        self.containerID = containerID
        self.name = name
        self.image = image
        self.status = status
        self.ports = ports
    }

    public var shortID: String {
        String(containerID.prefix(12))
    }

    public var displayName: String {
        name.isEmpty ? shortID : name
    }

    public var terminationTarget: ProcessTerminationTarget {
        .dockerContainer(id: containerID, name: name)
    }
}

public struct PortProcess: Equatable, Hashable, Identifiable, Sendable {
    public var id: String { "port-\(port)-\(terminationTarget.id)" }

    public let port: Int
    public let pid: Int
    public let name: String
    public let user: String?
    public let endpoint: String?
    public let commandLine: String
    public let terminationTarget: ProcessTerminationTarget

    public init(
        port: Int,
        pid: Int,
        name: String,
        user: String?,
        endpoint: String?,
        commandLine: String,
        terminationTarget: ProcessTerminationTarget? = nil
    ) {
        self.port = port
        self.pid = pid
        self.name = name
        self.user = user
        self.endpoint = endpoint
        self.commandLine = commandLine
        self.terminationTarget = terminationTarget ?? .process(pid: pid)
    }

    public var displayTarget: String {
        terminationTarget.displayLabel
    }

    public var canTerminate: Bool {
        terminationTarget.canTerminate
    }

    public var isDockerContainer: Bool {
        terminationTarget.isDockerContainer
    }

    public var isProtectedSystemProcess: Bool {
        terminationTarget.isProtectedSystemProcess
    }
}

public struct ProcessSnapshot: Equatable, Hashable, Identifiable, Sendable {
    public var id: Int { pid }

    public let pid: Int
    public let executable: String
    public let commandLine: String

    public init(pid: Int, executable: String, commandLine: String) {
        self.pid = pid
        self.executable = executable
        self.commandLine = commandLine
    }

    public var displayName: String {
        URL(fileURLWithPath: executable).lastPathComponent
    }
}

public struct RuleProcessMatch: Equatable, Hashable, Identifiable, Sendable {
    public var id: Int { process.pid }

    public let process: ProcessSnapshot
    public let rules: [String]

    public init(process: ProcessSnapshot, rules: [String]) {
        self.process = process
        self.rules = rules
    }
}

public enum LanguageMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case zhHans
    case english

    public var id: String { rawValue }
}

public enum AppearanceMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    public var id: String { rawValue }
}

public struct AppConfig: Codable, Equatable, Sendable {
    public var ports: [PortWatch]
    public var rules: [ProcessRule]
    public var scanInterval: TimeInterval
    public var monitoringEnabled: Bool
    public var languageMode: LanguageMode
    public var appearanceMode: AppearanceMode

    public init(
        ports: [PortWatch] = AppConfig.defaultPorts,
        rules: [ProcessRule] = AppConfig.defaultRules,
        scanInterval: TimeInterval = AppConfig.defaultScanInterval,
        monitoringEnabled: Bool = true,
        languageMode: LanguageMode = .system,
        appearanceMode: AppearanceMode = .system
    ) {
        self.ports = ports
        self.rules = rules
        self.scanInterval = scanInterval
        self.monitoringEnabled = monitoringEnabled
        self.languageMode = languageMode
        self.appearanceMode = appearanceMode
    }

    private enum CodingKeys: String, CodingKey {
        case ports
        case rules
        case scanInterval
        case monitoringEnabled
        case languageMode
        case appearanceMode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.ports = try container.decodeIfPresent([PortWatch].self, forKey: .ports) ?? Self.defaultPorts
        self.rules = try container.decodeIfPresent([ProcessRule].self, forKey: .rules) ?? Self.defaultRules
        self.scanInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .scanInterval) ?? Self.defaultScanInterval
        self.monitoringEnabled = try container.decodeIfPresent(Bool.self, forKey: .monitoringEnabled) ?? true
        self.languageMode = try container.decodeIfPresent(LanguageMode.self, forKey: .languageMode) ?? .system
        self.appearanceMode = try container.decodeIfPresent(AppearanceMode.self, forKey: .appearanceMode) ?? .system
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(ports, forKey: .ports)
        try container.encode(rules, forKey: .rules)
        try container.encode(scanInterval, forKey: .scanInterval)
        try container.encode(monitoringEnabled, forKey: .monitoringEnabled)
        try container.encode(languageMode, forKey: .languageMode)
        try container.encode(appearanceMode, forKey: .appearanceMode)
    }

    public static let defaultPorts: [PortWatch] = [
        PortWatch(port: 3000, label: "Next/React/Nuxt"),
        PortWatch(port: 3001, label: "Web Alt"),
        PortWatch(port: 3002, label: "Web Alt 2"),
        PortWatch(port: 4173, label: "Vite Preview"),
        PortWatch(port: 4200, label: "Angular"),
        PortWatch(port: 4321, label: "Astro"),
        PortWatch(port: 5000, label: "Flask/API"),
        PortWatch(port: 5173, label: "Vite"),
        PortWatch(port: 5174, label: "Vite Alt"),
        PortWatch(port: 5432, label: "Postgres"),
        PortWatch(port: 6006, label: "Storybook"),
        PortWatch(port: 6379, label: "Redis"),
        PortWatch(port: 8000, label: "Django/FastAPI"),
        PortWatch(port: 8080, label: "Spring/Tomcat/API"),
        PortWatch(port: 8787, label: "Wrangler"),
        PortWatch(port: 9000, label: "PHP/MinIO")
    ]

    public static let defaultRules: [ProcessRule] = [
        ProcessRule(pattern: "vite", label: "Vite"),
        ProcessRule(pattern: "next dev", label: "Next dev"),
        ProcessRule(pattern: "react-scripts start", label: "Create React App"),
        ProcessRule(pattern: "webpack-dev-server", label: "Webpack"),
        ProcessRule(pattern: "turbo dev", label: "Turborepo"),
        ProcessRule(pattern: "nuxt", label: "Nuxt"),
        ProcessRule(pattern: "astro dev", label: "Astro"),
        ProcessRule(pattern: "svelte-kit", label: "SvelteKit"),
        ProcessRule(pattern: "ng serve", label: "Angular"),
        ProcessRule(pattern: "remix dev", label: "Remix"),
        ProcessRule(pattern: "storybook", label: "Storybook"),
        ProcessRule(pattern: "expo start", label: "Expo"),
        ProcessRule(pattern: "nodemon", label: "Nodemon"),
        ProcessRule(pattern: "ts-node-dev", label: "ts-node-dev"),
        ProcessRule(pattern: "uvicorn", label: "Uvicorn"),
        ProcessRule(pattern: "fastapi dev", label: "FastAPI"),
        ProcessRule(pattern: "flask run", label: "Flask"),
        ProcessRule(pattern: "manage.py runserver", label: "Django"),
        ProcessRule(pattern: "python -m http.server", label: "Python static"),
        ProcessRule(pattern: "rails server", label: "Rails"),
        ProcessRule(pattern: "spring-boot:run", label: "Spring Boot"),
        ProcessRule(pattern: "wrangler", label: "Wrangler")
    ]

    public static let defaultScanInterval: TimeInterval = 30
}
