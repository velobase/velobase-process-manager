import Foundation

public enum ProcessScannerError: Error, LocalizedError, Sendable {
    case commandFailed(command: String, status: Int32, stderr: String)
    case dockerCLIUnavailable
    case dockerHostProtected(pid: Int)
    case systemProcessProtected(pid: Int)

    public var errorDescription: String? {
        switch self {
        case .commandFailed(let command, let status, let stderr):
            let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if detail.isEmpty {
                return "\(command) failed with status \(status)."
            }

            return "\(command) failed with status \(status): \(detail)"
        case .dockerCLIUnavailable:
            return "Docker CLI was not found, so the mapped container could not be stopped."
        case .dockerHostProtected:
            return "This is a Docker Desktop port proxy. Stop the mapped container instead of killing Docker Desktop."
        case .systemProcessProtected:
            return "This is an Apple system process and cannot be terminated directly."
        }
    }
}

public struct ProcessScanner: Sendable {
    private let runner: CommandRunner

    public init(runner: CommandRunner = CommandRunner()) {
        self.runner = runner
    }

    public func scanPorts(
        _ watches: [PortWatch],
        processSnapshots: [ProcessSnapshot]? = nil,
        dockerContainers knownDockerContainers: [DockerPublishedContainer]? = nil
    ) -> [PortProcess] {
        let watchedPorts = Set(watches.filter(\.enabled).map(\.port))

        guard !watchedPorts.isEmpty else {
            return []
        }

        guard let output = try? runner.run(
            "/usr/sbin/lsof",
            arguments: ["-nP", "-iTCP", "-sTCP:LISTEN", "-F", "pcLn"]
        ).stdout else {
            return []
        }

        let rawProcesses = Self.parseLsofFieldOutput(output, watchedPorts: watchedPorts)

        guard !rawProcesses.isEmpty else {
            return []
        }

        let commandLines = Dictionary(
            uniqueKeysWithValues: (processSnapshots ?? listProcesses()).map { ($0.pid, $0.commandLine) }
        )
        let processes = rawProcesses.map { process in
            let commandLine = commandLines[process.pid] ?? process.commandLine

            guard !commandLine.isEmpty else {
                return process
            }

            return PortProcess(
                port: process.port,
                pid: process.pid,
                name: process.name,
                user: process.user,
                endpoint: process.endpoint,
                commandLine: commandLine
            )
        }
        let dockerContainers = processes.contains(where: isDockerHostProcess)
            ? (knownDockerContainers ?? dockerPublishedContainers())
            : []
        let resolvedProcesses = Dictionary(grouping: processes, by: \.port)
            .flatMap { port, processes in
                dockerAwarePortProcesses(processes, port: port, containers: dockerContainers)
            }

        var seenIDs = Set<String>()
        return systemAwarePortProcesses(resolvedProcesses)
            .filter { seenIDs.insert($0.id).inserted }
            .sorted { lhs, rhs in
                if lhs.port == rhs.port { return lhs.pid < rhs.pid }
                return lhs.port < rhs.port
            }
    }

    public func scanRules(_ rules: [ProcessRule], processSnapshots: [ProcessSnapshot]? = nil) -> [RuleProcessMatch] {
        let activeRules = rules.filter {
            $0.enabled && !$0.pattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        guard !activeRules.isEmpty else {
            return []
        }

        let processes = (processSnapshots ?? listProcesses()).filter {
            $0.pid != Int(ProcessInfo.processInfo.processIdentifier)
        }

        var matches: [Int: RuleProcessMatch] = [:]

        for process in processes {
            let matchedRules = activeRules
                .filter { Self.ruleMatches($0, process: process) }
                .map(\.displayName)

            guard !matchedRules.isEmpty else {
                continue
            }

            matches[process.pid] = RuleProcessMatch(process: process, rules: matchedRules)
        }

        return matches.values.sorted { $0.process.pid < $1.process.pid }
    }

    public func scanDockerContainers() -> [DockerPublishedContainer] {
        dockerPublishedContainers()
            .sorted { lhs, rhs in
                let lhsName = lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName)
                if lhsName != .orderedSame {
                    return lhsName == .orderedAscending
                }

                return lhs.shortID < rhs.shortID
            }
    }

    public func terminate(pid: Int, force: Bool = false) throws {
        try terminate(.process(pid: pid), force: force)
    }

    public func terminate(_ target: ProcessTerminationTarget, force: Bool = false) throws {
        switch target {
        case .process(let pid):
            if isProtectedDockerHostProcess(pid: pid) {
                throw ProcessScannerError.dockerHostProtected(pid: pid)
            }

            if isProtectedSystemProcess(pid: pid) {
                throw ProcessScannerError.systemProcessProtected(pid: pid)
            }

            let signal = force ? "-KILL" : "-TERM"
            _ = try runChecked("/bin/kill", arguments: [signal, "\(pid)"])
        case .dockerContainer(let id, _):
            guard let docker = dockerExecutable() else {
                throw ProcessScannerError.dockerCLIUnavailable
            }

            let action = force ? "kill" : "stop"
            _ = try runChecked(docker, arguments: [action, id])
        case .protectedDockerHost(let pid):
            throw ProcessScannerError.dockerHostProtected(pid: pid)
        case .protectedSystemProcess(let pid, _):
            throw ProcessScannerError.systemProcessProtected(pid: pid)
        }
    }

    public func scanPort(_ port: Int) -> [PortProcess] {
        guard let output = try? runner.run(
            "/usr/sbin/lsof",
            arguments: ["-nP", "-iTCP:\(port)", "-sTCP:LISTEN", "-F", "pcLn"]
        ).stdout else {
            return []
        }

        let processes = Self.parseLsofFieldOutput(output, port: port).map { process in
            let commandLine = commandLine(for: process.pid)
            guard !commandLine.isEmpty else {
                return process
            }

            return PortProcess(
                port: process.port,
                pid: process.pid,
                name: process.name,
                user: process.user,
                endpoint: process.endpoint,
                commandLine: commandLine
            )
        }

        return systemAwarePortProcesses(dockerAwarePortProcesses(processes, port: port))
    }

    public func listProcesses() -> [ProcessSnapshot] {
        guard let output = try? runner.run(
            "/bin/ps",
            arguments: ["-axo", "pid=,comm=,command="]
        ).stdout else {
            return []
        }

        return Self.parseProcessList(output)
    }

    public func commandLine(for pid: Int) -> String {
        guard let output = try? runner.run(
            "/bin/ps",
            arguments: ["-p", "\(pid)", "-o", "command="]
        ).stdout else {
            return ""
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func parseDockerPublishedContainers(_ output: String) -> [DockerPublishedContainer] {
        output.split(whereSeparator: \.isNewline).compactMap { rawLine in
            let pieces = rawLine.split(separator: "\t", maxSplits: 4, omittingEmptySubsequences: false)

            guard pieces.count == 3 || pieces.count == 5 else {
                return nil
            }

            let containerID = String(pieces[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            let name = String(pieces[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            let image = pieces.count == 5
                ? String(pieces[2]).trimmingCharacters(in: .whitespacesAndNewlines)
                : ""
            let status = pieces.count == 5
                ? String(pieces[3]).trimmingCharacters(in: .whitespacesAndNewlines)
                : ""
            let portsIndex = pieces.count == 5 ? 4 : 2
            let ports = String(pieces[portsIndex]).trimmingCharacters(in: .whitespacesAndNewlines)

            guard !containerID.isEmpty else {
                return nil
            }

            return DockerPublishedContainer(
                containerID: containerID,
                name: name,
                image: image,
                status: status,
                ports: ports
            )
        }
    }

    public static func parseDockerPublishedContainers(_ output: String, hostPort: Int) -> [DockerPublishedContainer] {
        parseDockerPublishedContainers(output).filter {
            dockerPorts($0.ports, publishHostPort: hostPort)
        }
    }

    public static func isProtectedDockerHostCommand(_ command: String) -> Bool {
        let normalized = command.lowercased()
        return dockerHostProcessMarkers.contains { normalized.contains($0) }
    }

    public static func isProtectedSystemProcessCommand(_ command: String) -> Bool {
        protectedSystemProcessPathMarkers.contains { command.contains($0) }
    }

    public static func parseLsofFieldOutput(_ output: String, port: Int) -> [PortProcess] {
        var results: [PortProcess] = []
        var pid: Int?
        var name = ""
        var user: String?
        var endpoint: String?

        func flush() {
            guard let currentPid = pid else {
                return
            }

            results.append(
                PortProcess(
                    port: port,
                    pid: currentPid,
                    name: name.isEmpty ? "unknown" : name,
                    user: user,
                    endpoint: endpoint,
                    commandLine: name
                )
            )
        }

        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = String(rawLine)
            guard let marker = line.first else {
                continue
            }

            let value = String(line.dropFirst())

            switch marker {
            case "p":
                flush()
                pid = Int(value)
                name = ""
                user = nil
                endpoint = nil
            case "c":
                name = value
            case "L":
                user = value
            case "n":
                endpoint = value
            default:
                continue
            }
        }

        flush()
        return results
    }

    public static func parseLsofFieldOutput(_ output: String, watchedPorts: Set<Int>) -> [PortProcess] {
        var results: [PortProcess] = []
        var pid: Int?
        var name = ""
        var user: String?
        var endpoints: [String] = []

        func flush() {
            guard let currentPid = pid else {
                return
            }

            for endpoint in endpoints {
                guard
                    let port = listeningPort(in: endpoint),
                    watchedPorts.contains(port)
                else {
                    continue
                }

                results.append(
                    PortProcess(
                        port: port,
                        pid: currentPid,
                        name: name.isEmpty ? "unknown" : name,
                        user: user,
                        endpoint: endpoint,
                        commandLine: name
                    )
                )
            }
        }

        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = String(rawLine)
            guard let marker = line.first else {
                continue
            }

            let value = String(line.dropFirst())

            switch marker {
            case "p":
                flush()
                pid = Int(value)
                name = ""
                user = nil
                endpoints = []
            case "c":
                name = value
            case "L":
                user = value
            case "n":
                endpoints.append(value)
            default:
                continue
            }
        }

        flush()
        return results
    }

    public static func parseProcessList(_ output: String) -> [ProcessSnapshot] {
        output.split(whereSeparator: \.isNewline).compactMap { rawLine in
            let pieces = rawLine.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)

            guard pieces.count >= 2, let pid = Int(pieces[0]) else {
                return nil
            }

            let executable = String(pieces[1])
            let commandLine = pieces.count == 3 ? String(pieces[2]) : executable

            return ProcessSnapshot(pid: pid, executable: executable, commandLine: commandLine)
        }
    }

    public static func ruleMatches(_ rule: ProcessRule, process: ProcessSnapshot) -> Bool {
        let rawPattern = rule.pattern.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !rawPattern.isEmpty else {
            return false
        }

        let haystack = "\(process.executable) \(process.commandLine)"

        if rawPattern.hasPrefix("/") && rawPattern.hasSuffix("/") && rawPattern.count > 2 {
            let regexPattern = String(rawPattern.dropFirst().dropLast())

            guard let regex = try? NSRegularExpression(
                pattern: regexPattern,
                options: [.caseInsensitive]
            ) else {
                return false
            }

            let range = NSRange(haystack.startIndex..<haystack.endIndex, in: haystack)
            return regex.firstMatch(in: haystack, range: range) != nil
        }

        return haystack.range(of: rawPattern, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    private func dockerAwarePortProcesses(
        _ processes: [PortProcess],
        port: Int,
        containers allContainers: [DockerPublishedContainer]? = nil
    ) -> [PortProcess] {
        let dockerHosts = processes.filter(isDockerHostProcess)

        guard !dockerHosts.isEmpty else {
            return processes
        }

        let containers = (allContainers ?? dockerPublishedContainers()).filter {
            Self.dockerPorts($0.ports, publishHostPort: port)
        }
        let nonDockerProcesses = processes.filter { !isDockerHostProcess($0) }

        guard !containers.isEmpty else {
            return nonDockerProcesses + dockerHosts.map { process in
                PortProcess(
                    port: process.port,
                    pid: process.pid,
                    name: "Docker Desktop",
                    user: process.user,
                    endpoint: process.endpoint,
                    commandLine: "Docker Desktop port proxy for :\(port). Container could not be resolved.",
                    terminationTarget: .protectedDockerHost(pid: process.pid)
                )
            }
        }

        let hostProcess = dockerHosts[0]
        let dockerProcesses = containers.map { container in
            PortProcess(
                port: port,
                pid: hostProcess.pid,
                name: container.name.isEmpty ? container.shortID : container.name,
                user: hostProcess.user,
                endpoint: hostProcess.endpoint,
                commandLine: "Docker container \(container.name.isEmpty ? container.shortID : container.name) (\(container.shortID)) · \(container.ports)",
                terminationTarget: .dockerContainer(id: container.containerID, name: container.name)
            )
        }

        return nonDockerProcesses + dockerProcesses
    }

    private func dockerPublishedContainers(for port: Int) -> [DockerPublishedContainer] {
        dockerPublishedContainers().filter {
            Self.dockerPorts($0.ports, publishHostPort: port)
        }
    }

    private func dockerPublishedContainers() -> [DockerPublishedContainer] {
        guard let docker = dockerExecutable() else {
            return []
        }

        guard let result = try? runner.run(
            docker,
            arguments: ["ps", "--format", "{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"]
        ), result.status == 0 else {
            return []
        }

        return Self.parseDockerPublishedContainers(result.stdout)
    }

    private func dockerExecutable() -> String? {
        for path in Self.dockerExecutableCandidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }

        guard
            let result = try? runner.run("/usr/bin/which", arguments: ["docker"]),
            result.status == 0
        else {
            return nil
        }

        let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
    }

    private func runChecked(_ executable: String, arguments: [String]) throws -> CommandResult {
        let result = try runner.run(executable, arguments: arguments)

        guard result.status == 0 else {
            throw ProcessScannerError.commandFailed(
                command: ([executable] + arguments).joined(separator: " "),
                status: result.status,
                stderr: result.stderr
            )
        }

        return result
    }

    private func isDockerHostProcess(_ process: PortProcess) -> Bool {
        Self.isProtectedDockerHostCommand(process.name) || Self.isProtectedDockerHostCommand(process.commandLine)
    }

    private func isProtectedDockerHostProcess(pid: Int) -> Bool {
        Self.isProtectedDockerHostCommand(commandLine(for: pid))
    }

    private func systemAwarePortProcesses(_ processes: [PortProcess]) -> [PortProcess] {
        processes.map { process in
            guard process.terminationTarget.isPlainProcess, isProtectedSystemProcess(process) else {
                return process
            }

            let displayName = Self.processDisplayName(commandLine: process.commandLine, fallback: process.name)
            return PortProcess(
                port: process.port,
                pid: process.pid,
                name: displayName,
                user: process.user,
                endpoint: process.endpoint,
                commandLine: process.commandLine,
                terminationTarget: .protectedSystemProcess(pid: process.pid, name: displayName)
            )
        }
    }

    private func isProtectedSystemProcess(_ process: PortProcess) -> Bool {
        Self.isProtectedSystemProcessCommand(process.commandLine)
    }

    private func isProtectedSystemProcess(pid: Int) -> Bool {
        Self.isProtectedSystemProcessCommand(commandLine(for: pid))
    }

    private static func processDisplayName(commandLine: String, fallback: String) -> String {
        let executable = commandLine
            .split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? ""

        guard !executable.isEmpty else {
            return fallback
        }

        let components = executable.split(separator: "/").map(String.init)
        if let bundleName = components.first(where: { $0.hasSuffix(".app") }) {
            return String(bundleName.dropLast(4))
        }

        return components.last ?? fallback
    }

    private static func listeningPort(in endpoint: String) -> Int? {
        let firstToken = endpoint
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ", maxSplits: 1)
            .first
            .map(String.init) ?? ""
        let portToken = firstToken
            .split(separator: ":")
            .last
            .map(String.init) ?? ""
        let cleaned = portToken.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        return Int(cleaned)
    }

    private static func dockerPorts(_ ports: String, publishHostPort hostPort: Int) -> Bool {
        ports.split(separator: ",").contains { rawMapping in
            dockerPortMapping(String(rawMapping), publishesHostPort: hostPort)
        }
    }

    private static func dockerPortMapping(_ mapping: String, publishesHostPort hostPort: Int) -> Bool {
        let trimmed = mapping.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let arrowRange = trimmed.range(of: "->") else {
            return false
        }

        let hostSide = String(trimmed[..<arrowRange.lowerBound])
        let hostPortToken = hostSide.split(separator: ":").last.map(String.init) ?? hostSide
        return dockerPortToken(hostPortToken, contains: hostPort)
    }

    private static func dockerPortToken(_ token: String, contains hostPort: Int) -> Bool {
        let cleaned = token
            .trimmingCharacters(in: CharacterSet(charactersIn: "[] "))
            .split(separator: "/", maxSplits: 1)
            .first
            .map(String.init) ?? ""
        let bounds = cleaned.split(separator: "-", maxSplits: 1).compactMap { Int($0) }

        if bounds.count == 2 {
            let lower = min(bounds[0], bounds[1])
            let upper = max(bounds[0], bounds[1])
            return (lower...upper).contains(hostPort)
        }

        return Int(cleaned) == hostPort
    }

    private static let dockerExecutableCandidates = [
        "/usr/local/bin/docker",
        "/opt/homebrew/bin/docker",
        "/Applications/Docker.app/Contents/Resources/bin/docker"
    ]

    private static let dockerHostProcessMarkers = [
        "com.docker.backend",
        "com.docke",
        "com.docker.vpnkit",
        "com.docker.vmnetd",
        "com.docker.hyperkit",
        "docker-proxy",
        "vpnkit"
    ]

    private static let protectedSystemProcessPathMarkers = [
        "/System/Library/",
        "/System/Applications/",
        "/usr/libexec/"
    ]
}
