import AppKit
import ProcessManagerCore
import SwiftUI

struct MenuView: View {
    @EnvironmentObject private var monitor: ProcessMonitor
    @EnvironmentObject private var navigation: AppNavigation

    private var detectedTargets: [DetectedTarget] {
        DetectedTarget.build(monitor: monitor)
    }

    var body: some View {
        ZStack {
            switch navigation.screen {
            case .dashboard:
                dashboard
                    .transition(.move(edge: .leading).combined(with: .opacity))
            case .settings:
                SettingsView(
                    onBack: { navigation.showDashboard() },
                    onSave: { navigation.showDashboard() }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .background(AppPalette.windowBackground)
        .frame(minWidth: 520, idealWidth: 540, maxWidth: .infinity, minHeight: 560, idealHeight: 680, maxHeight: .infinity)
        .preferredColorScheme(monitor.appearanceMode.colorScheme)
        .animation(AppMotion.page, value: navigation.screen)
    }

    private var dashboard: some View {
        VStack(alignment: .leading, spacing: 0) {
            statusHeader

            if let errorMessage = monitor.errorMessage {
                ErrorBanner(message: errorMessage)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    targetList
                }
                .padding(16)
            }
        }
        .animation(AppMotion.content, value: monitor.activeCount)
        .animation(AppMotion.content, value: monitor.isScanning)
        .animation(AppMotion.content, value: monitor.portProcesses)
        .animation(AppMotion.content, value: monitor.ruleMatches)
        .animation(AppMotion.content, value: monitor.dockerContainers)
    }

    private var statusHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                StatusMark(
                    symbol: monitor.statusSymbol,
                    color: statusColor
                )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(monitor.t(.appName))
                            .font(.title3.weight(.semibold))
                            .lineLimit(1)

                        StatusPill(text: monitor.statusTitle, color: statusColor)
                    }

                    HStack(spacing: 7) {
                        Text(monitor.statusMessage)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        if let lastScanDate = monitor.lastScanDate {
                            Text("·")
                            Text(lastScanDate, style: .time)
                                .monospacedDigit()
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 10)

                headerActions
            }

            HStack(spacing: 8) {
                MetricChip(value: "\(monitor.activeCount)", label: monitor.t(.processesTab), color: statusColor)
            }
        }
        .padding(16)
        .background {
            Rectangle()
                .fill(AppPalette.headerBackground)
        }
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var headerActions: some View {
        HStack(spacing: 6) {
            Button {
                monitor.scanNow()
            } label: {
                ScanningGlyph(active: monitor.isScanning)
            }
            .buttonStyle(ToolbarIconButtonStyle(tint: AppPalette.idleColor))
            .disabled(!monitor.monitoringEnabled || monitor.isScanning)
            .help(monitor.t(.scan))

            Button {
                monitor.toggleMonitoring()
            } label: {
                Image(systemName: monitor.monitoringEnabled ? "pause.fill" : "play.fill")
            }
            .buttonStyle(ToolbarIconButtonStyle(tint: AppPalette.idleColor))
            .help(monitor.monitoringEnabled ? monitor.t(.pauseMonitoring) : monitor.t(.resumeMonitoring))

            Button {
                AppActions.showSettings()
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .buttonStyle(ToolbarIconButtonStyle(tint: .secondary))
            .help(monitor.t(.settings))

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(ToolbarIconButtonStyle(tint: .red))
            .help(monitor.t(.quit))
        }
    }

    @ViewBuilder
    private var targetList: some View {
        if !monitor.monitoringEnabled {
            EmptyState(text: monitor.t(.monitoringPaused), systemImage: "pause.circle")
                .transition(.opacity)
        } else if detectedTargets.isEmpty {
            EmptyState(text: monitor.t(.noTargetProcesses), systemImage: "checkmark.circle")
                .transition(.opacity)
        } else {
            LazyVStack(spacing: 8) {
                ForEach(detectedTargets) { target in
                    DetectedTargetRow(target: target)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    private var statusColor: Color {
        if monitor.activeCount > 0 { return AppPalette.runningColor }
        return AppPalette.idleColor
    }
}

private enum AppPalette {
    static let windowBackground = Color(nsColor: .windowBackgroundColor)
    static let headerBackground = Color(nsColor: .controlBackgroundColor).opacity(0.72)
    static let rowBackground = Color(nsColor: .controlBackgroundColor).opacity(0.82)
    static let rowBorder = Color.primary.opacity(0.08)
    static let insetBackground = Color(nsColor: .textBackgroundColor).opacity(0.42)
    static let idleColor = Color(nsColor: .secondaryLabelColor)
    static let runningColor = Color.orange
}

private enum AppMotion {
    static let page = Animation.spring(response: 0.30, dampingFraction: 0.92, blendDuration: 0.10)
    static let content = Animation.spring(response: 0.28, dampingFraction: 0.93, blendDuration: 0.12)
    static let control = Animation.spring(response: 0.20, dampingFraction: 0.86, blendDuration: 0.08)
}

private enum TargetReasonKind: Int, Hashable {
    case port
    case rule
    case docker

    var systemImage: String {
        switch self {
        case .port:
            "network"
        case .rule:
            "scope"
        case .docker:
            "shippingbox.fill"
        }
    }

    var tint: Color {
        switch self {
        case .port:
            Color.orange
        case .rule:
            Color(red: 0.95, green: 0.46, blue: 0.08)
        case .docker:
            Color(red: 0.86, green: 0.39, blue: 0.10)
        }
    }
}

private struct TargetReason: Hashable, Identifiable {
    let kind: TargetReasonKind
    let text: String

    var id: String {
        "\(kind.rawValue)-\(text)"
    }
}

private struct DetectedTarget: Equatable, Identifiable {
    let id: String
    var title: String
    var subtitle: String
    var identityLabel: String
    var systemImage: String
    var terminationTarget: ProcessTerminationTarget
    var canTerminate: Bool
    var showsSystemBadge: Bool
    var reasons: [TargetReason]

    var isDockerContainer: Bool {
        terminationTarget.isDockerContainer
    }

    private var primaryReasonRank: Int {
        reasons.map(\.kind.rawValue).min() ?? Int.max
    }

    private var primaryReasonText: String {
        reasons.first { $0.kind.rawValue == primaryReasonRank }?.text ?? ""
    }

    mutating func addReason(_ reason: TargetReason) {
        guard !reasons.contains(reason) else {
            return
        }

        reasons.append(reason)
        reasons.sort { lhs, rhs in
            if lhs.kind.rawValue == rhs.kind.rawValue {
                return lhs.text.localizedCaseInsensitiveCompare(rhs.text) == .orderedAscending
            }

            return lhs.kind.rawValue < rhs.kind.rawValue
        }
    }

    @MainActor
    static func build(monitor: ProcessMonitor) -> [DetectedTarget] {
        var targets: [String: DetectedTarget] = [:]
        var portLookup: [Int: PortWatch] = [:]

        for port in monitor.ports where port.enabled {
            portLookup[port.port] = port
        }

        for process in monitor.portProcesses {
            merge(
                DetectedTarget(
                    id: process.terminationTarget.id,
                    title: process.name,
                    subtitle: process.commandLine,
                    identityLabel: process.displayTarget,
                    systemImage: process.isDockerContainer
                        ? "shippingbox.fill"
                        : (process.isProtectedSystemProcess ? "gearshape.2.fill" : "terminal"),
                    terminationTarget: process.terminationTarget,
                    canTerminate: process.canTerminate,
                    showsSystemBadge: process.isProtectedSystemProcess,
                    reasons: [portReason(port: process.port, watch: portLookup[process.port])]
                ),
                into: &targets
            )
        }

        for match in monitor.ruleMatches {
            let command = "\(match.process.executable) \(match.process.commandLine)"
            let target = ruleTerminationTarget(match: match, command: command)

            merge(
                DetectedTarget(
                    id: target.id,
                    title: match.process.displayName,
                    subtitle: match.process.commandLine,
                    identityLabel: target.displayLabel,
                    systemImage: target.isProtectedSystemProcess ? "gearshape.2.fill" : "terminal",
                    terminationTarget: target,
                    canTerminate: target.canTerminate,
                    showsSystemBadge: target.isProtectedSystemProcess,
                    reasons: match.rules.map { TargetReason(kind: .rule, text: $0) }
                ),
                into: &targets
            )
        }

        for container in monitor.dockerContainers {
            let target = container.terminationTarget

            merge(
                DetectedTarget(
                    id: target.id,
                    title: container.displayName,
                    subtitle: dockerSubtitle(container, monitor: monitor),
                    identityLabel: target.displayLabel,
                    systemImage: "shippingbox.fill",
                    terminationTarget: target,
                    canTerminate: target.canTerminate,
                    showsSystemBadge: false,
                    reasons: [TargetReason(kind: .docker, text: "Docker")]
                ),
                into: &targets
            )
        }

        return targets.values.sorted { lhs, rhs in
            if lhs.primaryReasonRank != rhs.primaryReasonRank {
                return lhs.primaryReasonRank < rhs.primaryReasonRank
            }

            let reasonOrder = lhs.primaryReasonText.localizedCaseInsensitiveCompare(rhs.primaryReasonText)
            if reasonOrder != .orderedSame {
                return reasonOrder == .orderedAscending
            }

            let titleOrder = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
            if titleOrder != .orderedSame {
                return titleOrder == .orderedAscending
            }

            return lhs.id < rhs.id
        }
    }

    private static func merge(_ target: DetectedTarget, into targets: inout [String: DetectedTarget]) {
        guard var existing = targets[target.id] else {
            targets[target.id] = target
            return
        }

        for reason in target.reasons {
            existing.addReason(reason)
        }

        if existing.subtitle.isEmpty || existing.subtitle == existing.title {
            existing.subtitle = target.subtitle
        }

        if existing.identityLabel.isEmpty {
            existing.identityLabel = target.identityLabel
        }

        if existing.systemImage == "terminal", target.systemImage != "terminal" {
            existing.systemImage = target.systemImage
        }

        existing.canTerminate = existing.canTerminate || target.canTerminate
        existing.showsSystemBadge = existing.showsSystemBadge || target.showsSystemBadge
        targets[target.id] = existing
    }

    private static func portReason(port: Int, watch: PortWatch?) -> TargetReason {
        let label = watch?.label.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let text = label.isEmpty ? ":\(port)" : "\(label) :\(port)"
        return TargetReason(kind: .port, text: text)
    }

    private static func ruleTerminationTarget(match: RuleProcessMatch, command: String) -> ProcessTerminationTarget {
        if ProcessScanner.isProtectedSystemProcessCommand(command) {
            return .protectedSystemProcess(pid: match.process.pid, name: match.process.displayName)
        }

        if ProcessScanner.isProtectedDockerHostCommand(command) {
            return .protectedDockerHost(pid: match.process.pid)
        }

        return .process(pid: match.process.pid)
    }

    @MainActor
    private static func dockerSubtitle(_ container: DockerPublishedContainer, monitor: ProcessMonitor) -> String {
        var pieces: [String] = []

        if !container.image.isEmpty {
            pieces.append(container.image)
        }

        pieces.append(container.ports.isEmpty ? monitor.t(.noPublishedPorts) : container.ports)

        if !container.status.isEmpty {
            pieces.append(container.status)
        }

        return pieces.joined(separator: " · ")
    }
}

private struct DetectedTargetRow: View {
    @EnvironmentObject private var monitor: ProcessMonitor
    let target: DetectedTarget
    @State private var revealsSystemAction = false

    private var actionTarget: ProcessTerminationTarget {
        guard
            revealsSystemAction,
            let overrideTarget = target.terminationTarget.systemOverrideTarget
        else {
            return target.terminationTarget
        }

        return overrideTarget
    }

    private var showsSystemBadge: Bool {
        target.showsSystemBadge && !revealsSystemAction
    }

    private var canTerminate: Bool {
        target.canTerminate || actionTarget.canTerminate
    }

    var body: some View {
        ProcessRow(
            title: target.title,
            subtitle: target.subtitle,
            trailing: target.identityLabel,
            reasons: target.reasons,
            systemImage: target.systemImage,
            canTerminate: canTerminate,
            actionMode: monitor.terminationButtonMode(for: actionTarget),
            terminateLabel: target.isDockerContainer ? monitor.t(.stopContainer) : monitor.t(.sendTerm),
            forceTerminateLabel: target.isDockerContainer ? monitor.t(.killContainer) : monitor.t(.forceKill),
            disabledHelp: target.showsSystemBadge ? monitor.t(.systemProcessProtected) : monitor.t(.dockerProxyProtected),
            showsSystemBadge: showsSystemBadge,
            systemBadgeHelp: monitor.t(.systemProcessRevealHelp),
            revealSystemAction: {
                withAnimation(AppMotion.content) {
                    revealsSystemAction = true
                }
            },
            terminate: { monitor.terminate(actionTarget) },
            forceTerminate: { monitor.terminate(actionTarget, force: true) }
        )
        .padding(11)
        .background(AppPalette.rowBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppPalette.rowBorder, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { isHovering in
            guard !isHovering, revealsSystemAction else {
                return
            }

            withAnimation(AppMotion.content) {
                revealsSystemAction = false
            }
        }
    }
}

private struct ReasonChip: View {
    let reason: TargetReason

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: reason.kind.systemImage)
                .font(.system(size: 9, weight: .semibold))

            Text(reason.text)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(reason.kind.tint)
        .padding(.horizontal, 7)
        .frame(height: 21)
        .background(reason.kind.tint.opacity(0.11), in: Capsule())
        .overlay {
            Capsule()
                .stroke(reason.kind.tint.opacity(0.18), lineWidth: 1)
        }
    }
}

private struct StatusMark: View {
    let symbol: String
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.16))
                .frame(width: 44, height: 44)

            Image(systemName: symbol)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(width: 52, height: 52)
    }
}

private struct StatusPill: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text(text)
                .font(.caption.weight(.medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12), in: Capsule())
        .foregroundStyle(color)
    }
}

private struct MetricChip: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .frame(minWidth: 20)

            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(AppPalette.insetBackground, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(color.opacity(0.14), lineWidth: 1)
        }
    }
}

private struct ScanningGlyph: View {
    let active: Bool

    @ViewBuilder
    var body: some View {
        if active {
            TimelineView(.animation) { timeline in
                let rotation = timeline.date.timeIntervalSinceReferenceDate * 220

                Image(systemName: "arrow.triangle.2.circlepath")
                    .rotationEffect(.degrees(rotation))
                    .animation(nil, value: rotation)
            }
            .frame(width: 16, height: 16)
        } else {
            Image(systemName: "arrow.triangle.2.circlepath")
                .frame(width: 16, height: 16)
        }
    }
}

private struct ToolbarIconButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 31, height: 31)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(configuration.isPressed ? tint.opacity(0.18) : AppPalette.insetBackground)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(tint.opacity(configuration.isPressed ? 0.28 : 0.12), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(AppMotion.control, value: configuration.isPressed)
    }
}

private struct RowIconButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(tint)
            .background(
                Circle()
                    .fill(configuration.isPressed ? tint.opacity(0.12) : Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.90 : 1)
            .animation(AppMotion.control, value: configuration.isPressed)
    }
}

private struct ProcessRow: View {
    @EnvironmentObject private var monitor: ProcessMonitor
    let title: String
    let subtitle: String
    let trailing: String
    var reasons: [TargetReason] = []
    let systemImage: String
    let canTerminate: Bool
    let actionMode: ProcessTerminationButtonMode
    let terminateLabel: String
    let forceTerminateLabel: String
    let disabledHelp: String
    let showsSystemBadge: Bool
    let systemBadgeHelp: String
    let revealSystemAction: (() -> Void)?
    let terminate: () -> Void
    let forceTerminate: () -> Void

    private var buttonIcon: String {
        switch actionMode {
        case .graceful:
            "xmark.circle.fill"
        case .waiting:
            "hourglass.circle.fill"
        case .force:
            "exclamationmark.octagon.fill"
        }
    }

    private var buttonHelp: String {
        guard canTerminate else {
            return disabledHelp
        }

        switch actionMode {
        case .graceful:
            return terminateLabel
        case .waiting:
            return monitor.t(.waitingForExit)
        case .force:
            return forceTerminateLabel
        }
    }

    private var buttonColor: Color {
        switch actionMode {
        case .graceful, .force:
            return .red
        case .waiting:
            return .secondary
        }
    }

    private var visibleReasons: [TargetReason] {
        Array(reasons.prefix(4))
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(AppPalette.insetBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .truncationMode(.middle)

                        if !trailing.isEmpty {
                            Text(trailing)
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 28)
                    }

                    if !reasons.isEmpty {
                        HStack(spacing: 5) {
                            ForEach(visibleReasons) { reason in
                                ReasonChip(reason: reason)
                            }

                            if reasons.count > visibleReasons.count {
                                Text("+\(reasons.count - visibleReasons.count)")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 7)
                                    .frame(height: 21)
                                    .background(AppPalette.insetBackground, in: Capsule())
                            }
                        }
                        .padding(.trailing, 28)
                    }

                    Text(subtitle.isEmpty ? title : subtitle)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                        .padding(.trailing, 28)
                }
            }

            if showsSystemBadge {
                Button {
                    revealSystemAction?()
                } label: {
                    SystemProcessBadge(text: monitor.t(.systemProcessBadge), isInteractive: revealSystemAction != nil)
                }
                .buttonStyle(.plain)
                .help(systemBadgeHelp)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.94, anchor: .trailing).combined(with: .opacity),
                    removal: .scale(scale: 0.98, anchor: .trailing).combined(with: .opacity)
                ))
            } else {
                Button(action: actionMode == .force ? forceTerminate : terminate) {
                    Image(systemName: buttonIcon)
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(RowIconButtonStyle(tint: buttonColor))
                .disabled(!canTerminate || actionMode == .waiting)
                .opacity((canTerminate && actionMode != .waiting) ? 1 : 0.42)
                .help(buttonHelp)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.82, anchor: .trailing).combined(with: .opacity),
                    removal: .scale(scale: 0.92, anchor: .trailing).combined(with: .opacity)
                ))
            }
        }
        .animation(AppMotion.content, value: showsSystemBadge)
        .animation(AppMotion.control, value: actionMode)
    }
}

private struct SystemProcessBadge: View {
    let text: String
    let isInteractive: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 10, weight: .semibold))

            Text(text)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)

            if isInteractive {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .opacity(0.72)
            }
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 7)
        .frame(height: 24)
        .background(AppPalette.insetBackground, in: Capsule())
        .contentShape(Capsule())
    }
}

private struct ErrorBanner: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.red)
            .lineLimit(2)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct EmptyState: View {
    let text: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .background(AppPalette.insetBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(11)
        .background(AppPalette.rowBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppPalette.rowBorder, lineWidth: 1)
        }
    }
}
