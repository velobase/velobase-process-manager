import Darwin
import Foundation
import ProcessManagerCore

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let lsofOutput = """
p12345
cnode
Lxxc
n*:3000
p22222
cpython3.12
Lxxc
n127.0.0.1:8000
"""

let portResults = ProcessScanner.parseLsofFieldOutput(lsofOutput, port: 3000)
expect(portResults.count == 2, "lsof parser should return two rows")
expect(portResults[0].pid == 12_345, "first lsof pid should parse")
expect(portResults[0].name == "node", "first lsof command should parse")
expect(portResults[1].endpoint == "127.0.0.1:8000", "second endpoint should parse")

let allPortsLsofOutput = """
p11111
cnode
Lxxc
n*:3000
p22222
ccom.docker.backend
Lxxc
n[::]:6379
p33333
cruby
Lxxc
n127.0.0.1:4567
"""

let watchedPortResults = ProcessScanner.parseLsofFieldOutput(
    allPortsLsofOutput,
    watchedPorts: [3000, 6379]
)
expect(watchedPortResults.count == 2, "batched lsof parser should only return watched ports")
expect(watchedPortResults[0].port == 3000, "batched lsof parser should parse wildcard host port")
expect(watchedPortResults[1].port == 6379, "batched lsof parser should parse IPv6 host port")

let dockerPsOutput = """
abc123def456\tweb\t0.0.0.0:3000->3000/tcp, :::3000->3000/tcp
def456abc123\tdb\t127.0.0.1:5432->5432/tcp
fedcba654321\tapi\t0.0.0.0:8000-8002->8000-8002/tcp
aaaaabbbbbcc\tinternal\t80/tcp
"""

let dockerWeb = ProcessScanner.parseDockerPublishedContainers(dockerPsOutput, hostPort: 3000)
expect(dockerWeb.count == 1, "docker parser should find published host port")
expect(dockerWeb[0].name == "web", "docker parser should preserve container name")
expect(
    ProcessScanner.parseDockerPublishedContainers(dockerPsOutput).count == 4,
    "docker parser should parse all containers once"
)

let dockerRange = ProcessScanner.parseDockerPublishedContainers(dockerPsOutput, hostPort: 8001)
expect(dockerRange.count == 1, "docker parser should support published port ranges")
expect(dockerRange[0].name == "api", "docker range parser should return matching container")

let detailedDockerPsOutput = """
abc123def456\tweb\tnginx:alpine\tUp 5 minutes\t0.0.0.0:3000->80/tcp
bbbbccccdddd\tworker\tqueue:latest\tUp 2 hours\t
"""

let detailedDockerContainers = ProcessScanner.parseDockerPublishedContainers(detailedDockerPsOutput)
expect(detailedDockerContainers.count == 2, "docker parser should support detailed ps format")
expect(detailedDockerContainers[0].image == "nginx:alpine", "docker parser should preserve image")
expect(detailedDockerContainers[0].status == "Up 5 minutes", "docker parser should preserve status")
expect(detailedDockerContainers[1].ports.isEmpty, "docker parser should preserve empty ports")

expect(
    ProcessScanner.isProtectedDockerHostCommand("/Applications/Docker.app/Contents/MacOS/com.docker.backend"),
    "docker backend should be recognized as protected"
)
expect(
    ProcessScanner.isProtectedSystemProcessCommand("/System/Library/CoreServices/ControlCenter.app/Contents/MacOS/ControlCenter"),
    "Control Center should be recognized as a protected system process"
)
let protectedSystemTarget = ProcessTerminationTarget.protectedSystemProcess(pid: 1070, name: "ControlCenter")
let overrideSystemTarget = protectedSystemTarget.systemOverrideTarget
expect(overrideSystemTarget?.id == protectedSystemTarget.id, "system override should keep target identity stable")
expect(overrideSystemTarget?.canTerminate == true, "system override should be terminable after user unlock")
expect(
    !ProcessScanner.isProtectedSystemProcessCommand("/opt/homebrew/bin/flask --app server run --port 5000"),
    "user development processes on port 5000 should remain terminable"
)

let psOutput = """
  123 /usr/local/bin/node node ./node_modules/vite/bin/vite.js --host
  456 /opt/homebrew/bin/python3 python3 -m http.server 8000
"""

let processes = ProcessScanner.parseProcessList(psOutput)
expect(processes.count == 2, "ps parser should return two rows")
expect(processes[0].displayName == "node", "displayName should use executable basename")
expect(processes[1].commandLine == "python3 -m http.server 8000", "command line should preserve spaces")

let keywordRule = ProcessRule(pattern: "VITE")
expect(
    ProcessScanner.ruleMatches(keywordRule, process: processes[0]),
    "keyword matching should be case insensitive"
)

let regexRule = ProcessRule(pattern: "/python\\d?(\\.\\d+)? -m http\\.server/")
let regexProcess = ProcessSnapshot(
    pid: 456,
    executable: "/opt/homebrew/bin/python3.12",
    commandLine: "python3.12 -m http.server 8000"
)
expect(
    ProcessScanner.ruleMatches(regexRule, process: regexProcess),
    "regex matching should work"
)

let legacyConfigJSON = """
{
  "ports": [],
  "rules": [],
  "scanInterval": 8,
  "monitoringEnabled": true
}
"""

let legacyConfigData = legacyConfigJSON.data(using: .utf8)!
let legacyConfig = try JSONDecoder().decode(AppConfig.self, from: legacyConfigData)
expect(legacyConfig.languageMode == .system, "legacy config should default language to system")
expect(legacyConfig.appearanceMode == .system, "legacy config should default appearance to system")
expect(AppConfig().scanInterval == 30, "new configs should default to 30 seconds")
expect(AppConfig.defaultPorts.map(\.port).contains(4200), "default ports should include Angular")
expect(AppConfig.defaultPorts.map(\.port).contains(4321), "default ports should include Astro")
expect(AppConfig.defaultPorts.map(\.port).contains(6006), "default ports should include Storybook")
expect(
    AppConfig.defaultPorts.allSatisfy { $0.label.range(of: "\\p{Han}", options: .regularExpression) == nil },
    "default port labels should be English"
)
expect(
    AppConfig.defaultRules.contains { $0.pattern == "react-scripts start" },
    "default rules should include Create React App"
)
expect(
    AppConfig.defaultRules.contains { $0.pattern == "ng serve" },
    "default rules should include Angular"
)

let missingIntervalConfigJSON = """
{
  "ports": [],
  "rules": [],
  "monitoringEnabled": true
}
"""

let missingIntervalConfigData = missingIntervalConfigJSON.data(using: .utf8)!
let missingIntervalConfig = try JSONDecoder().decode(AppConfig.self, from: missingIntervalConfigData)
expect(missingIntervalConfig.scanInterval == 30, "missing scan interval should default to 30 seconds")

print("ProcessManagerCheck passed.")
