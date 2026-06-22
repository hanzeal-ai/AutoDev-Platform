import SwiftUI
import AppKit

struct ProjectWorkflowOverviewSection: View {
    @ObservedObject var viewModel: ShellViewModel
    let snapshot: DeliveryWorkflowSnapshot?
    let detail: DeliveryExecutionDetail?
    @State private var now = Date()

    private let ticker = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        DashboardCard(title: "Workflow 总览") {
            VStack(alignment: .leading, spacing: 14) {
                header
                workflowGraph
            }
        }
        .onReceive(ticker) { now = $0 }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(snapshot?.projectName.isEmpty == false ? snapshot?.projectName ?? "项目" : "项目")
                    .font(.subheadline.weight(.semibold))
                Text(statusLine)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            WorkflowActivityBadge(
                activity: activity,
                detail: WorkflowActivityPresentation.detail(
                    for: activity,
                    snapshot: snapshot,
                    detail: detail,
                    now: now
                )
            )
            Button {
                Task { await viewModel.refreshSelectedProjectDetail() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("刷新 Workflow 状态")
        }
    }

    private var workflowGraph: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            WorkflowGraphView(
                phases: phases,
                currentStep: snapshot?.currentStep ?? "",
                artifactSummary: artifactSummary(for:),
                hasArtifactFile: { phase in phase.filePath?.isEmpty == false },
                onSelect: { phase in
                    viewModel.selectDetailStage(lifecycleStage(for: phase.stage))
                },
                onOpenArtifact: openArtifact(for:)
            )
            .padding(.vertical, 6)
        }
    }

    private var activity: DeliveryWorkflowActivityState {
        WorkflowActivityPresentation.activity(snapshot: snapshot, detail: detail, now: now)
    }

    private var phases: [DeliveryWorkflowPhase] {
        if let phases = snapshot?.phases, !phases.isEmpty {
            return phases
        }
        return DomainMapper.workflowStageOrder.map { stage in
            DeliveryWorkflowPhase(
                id: stage,
                stage: stage,
                title: fallbackTitle(for: stage),
                kind: "workflow-\(stage)",
                status: .pending,
                artifactID: nil,
                fileName: nil,
                filePath: nil
            )
        }
    }

    private var statusLine: String {
        guard let snapshot else {
            return "正在读取 workflow 状态"
        }
        if let error = snapshot.error, !error.isEmpty {
            return "当前步骤：\(title(for: snapshot.currentStep)) · \(error)"
        }
        return "当前步骤：\(title(for: snapshot.currentStep)) · \(WorkflowActivityPresentation.label(for: activity))"
    }

    private func title(for stage: String) -> String {
        phases.first(where: { $0.stage == stage })?.title ?? fallbackTitle(for: stage)
    }

    private func fallbackTitle(for stage: String) -> String {
        ProjectWorkflowStatusPresentation.overviewTitle(for: stage)
    }

    private func lifecycleStage(for workflowStage: String) -> DeliveryLifecycleStage {
        switch workflowStage {
        case "prd", "prd_review":
            return .prd
        default:
            return .development
        }
    }

    private func artifactSummary(for phase: DeliveryWorkflowPhase) -> String {
        if let fileName = phase.fileName, !fileName.isEmpty {
            return fileName
        }
        if let filePath = phase.filePath, !filePath.isEmpty {
            return URL(fileURLWithPath: filePath).lastPathComponent
        }
        if phase.stage == snapshot?.currentStep {
            let names = currentDetailFileNames
            if !names.isEmpty {
                return names.joined(separator: ", ")
            }
        }
        if phase.artifactID != nil {
            return phase.title
        }
        return "无产物"
    }

    private func openArtifact(for phase: DeliveryWorkflowPhase) {
        guard let filePath = phase.filePath, !filePath.isEmpty else {
            viewModel.selectDetailStage(lifecycleStage(for: phase.stage))
            return
        }
        viewModel.openFilePath(filePath)
    }

    private var currentDetailFileNames: [String] {
        let unitNames = (detail?.workUnits ?? []).map(\.title).filter { !$0.isEmpty }
        if !unitNames.isEmpty {
            return Array(unitNames.prefix(3))
        }
        let stepNames = (detail?.stepProgress ?? []).map(\.title).filter { !$0.isEmpty }
        return Array(stepNames.prefix(3))
    }
}

private struct WorkflowActivityBadge: View {
    let activity: DeliveryWorkflowActivityState
    let detail: String

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(WorkflowActivityPresentation.label(for: activity))
                .font(.caption.weight(.semibold))
                .foregroundColor(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.1), in: Capsule(style: .continuous))
        .help(detail)
    }

    private var color: Color {
        WorkflowActivityPresentation.color(for: activity)
    }
}

private struct WorkflowGraphView: View {
    @Environment(\.colorScheme) private var colorScheme

    let phases: [DeliveryWorkflowPhase]
    let currentStep: String
    let artifactSummary: (DeliveryWorkflowPhase) -> String
    let hasArtifactFile: (DeliveryWorkflowPhase) -> Bool
    let onSelect: (DeliveryWorkflowPhase) -> Void
    let onOpenArtifact: (DeliveryWorkflowPhase) -> Void

    var body: some View {
        let layout = WorkflowGraphGeometry.layout(for: phases, artifactSummary: artifactSummary)

        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(WorkflowGraphStyle.canvasBackground(for: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(WorkflowGraphStyle.canvasBorder(for: colorScheme), lineWidth: 1)
                )
            WorkflowGraphEdges(
                phases: phases,
                currentStep: currentStep,
                nodeFrames: layout.nodeFrames
            )
            ForEach(phases) { phase in
                let frame = layout.nodeFrames[phase.stage] ?? WorkflowGraphGeometry.fallbackFrame
                WorkflowNodeView(
                    phase: phase,
                    isCurrent: phase.stage == currentStep,
                    artifactSummary: artifactSummary(phase),
                    hasArtifactFile: hasArtifactFile(phase),
                    onSelect: { onSelect(phase) },
                    onOpenArtifact: { onOpenArtifact(phase) }
                )
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
            }
        }
        .frame(width: layout.size.width, height: layout.size.height)
    }
}

private enum WorkflowGraphGeometry {
    static let fallbackFrame = CGRect(x: 24, y: 44, width: 160, height: nodeHeight)

    private static let nodeHeight: CGFloat = 94
    private static let edgeInset: CGFloat = 24
    private static let rowTopY: CGFloat = 92
    private static let rowBottomY: CGFloat = 238
    private static let horizontalGap: CGFloat = 54
    private static let maxNodeWidth: CGFloat = 340
    private static let minNodeWidth: CGFloat = 136
    private static let nodePadding: CGFloat = 16

    static func layout(
        for phases: [DeliveryWorkflowPhase],
        artifactSummary: (DeliveryWorkflowPhase) -> String
    ) -> WorkflowGraphLayout {
        let phasesByStage = Dictionary(uniqueKeysWithValues: phases.map { ($0.stage, $0) })
        var frames: [String: CGRect] = [:]
        var cursor = edgeInset
        let topStages = ["prd", "prd_review", "development", "coding"]

        for stage in topStages {
            let width = nodeWidth(for: phasesByStage[stage], stage: stage, artifactSummary: artifactSummary)
            frames[stage] = CGRect(x: cursor, y: rowTopY - nodeHeight / 2, width: width, height: nodeHeight)
            cursor += width + horizontalGap
        }

        if let development = frames["development"] {
            let width = nodeWidth(for: phasesByStage["code_review"], stage: "code_review", artifactSummary: artifactSummary)
            frames["code_review"] = CGRect(
                x: development.midX - width / 2,
                y: rowBottomY - nodeHeight / 2,
                width: width,
                height: nodeHeight
            )
        }

        if let prdReview = frames["prd_review"] {
            let width = nodeWidth(for: phasesByStage["summary"], stage: "summary", artifactSummary: artifactSummary)
            frames["summary"] = CGRect(
                x: prdReview.midX - width / 2,
                y: rowBottomY - nodeHeight / 2,
                width: width,
                height: nodeHeight
            )
        }

        let maxX = max(cursor - horizontalGap + edgeInset, frames.values.map(\.maxX).max() ?? fallbackFrame.maxX + edgeInset)
        let maxY = (frames.values.map(\.maxY).max() ?? fallbackFrame.maxY) + edgeInset
        return WorkflowGraphLayout(nodeFrames: frames, size: CGSize(width: maxX, height: maxY))
    }

    private static func nodeWidth(
        for phase: DeliveryWorkflowPhase?,
        stage: String,
        artifactSummary: (DeliveryWorkflowPhase) -> String
    ) -> CGFloat {
        let statusText = phase.map { ProjectWorkflowStatusPresentation.label(for: $0.status) } ?? "等待"
        let title = ProjectWorkflowStatusPresentation.overviewTitle(for: stage)
        let artifact = phase.map(artifactSummary) ?? "无产物"
        let statusWidth = textWidth(statusText, font: NSFont.systemFont(ofSize: 11, weight: .semibold)) + 14
        let titleWidth = textWidth(title, font: NSFont.systemFont(ofSize: 18, weight: .semibold))
        let artifactWidth = textWidth(artifact, font: NSFont.systemFont(ofSize: 11))
        let contentWidth = max(statusWidth, titleWidth, artifactWidth)
        return min(max(contentWidth + nodePadding * 2, minNodeWidth), maxNodeWidth)
    }

    private static func textWidth(_ text: String, font: NSFont) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: font]).width.rounded(.up)
    }
}

private struct WorkflowGraphLayout {
    let nodeFrames: [String: CGRect]
    let size: CGSize
}

private extension Dictionary where Key == String, Value == CGRect {
    func frame(for stage: String) -> CGRect {
        self[stage] ?? WorkflowGraphGeometry.fallbackFrame
    }
}

private extension CGRect {
    var topMid: CGPoint {
        CGPoint(x: midX, y: minY)
    }

    var bottomMid: CGPoint {
        CGPoint(x: midX, y: maxY)
    }

    var leftMid: CGPoint {
        CGPoint(x: minX, y: midY)
    }

    var rightMid: CGPoint {
        CGPoint(x: maxX, y: midY)
    }

    func topPoint(offsetX: CGFloat) -> CGPoint {
        CGPoint(x: midX + offsetX, y: minY)
    }

    func bottomPoint(offsetX: CGFloat) -> CGPoint {
        CGPoint(x: midX + offsetX, y: maxY)
    }

    func limitedHorizontalOffset(_ value: CGFloat) -> CGFloat {
        let limit = max(width / 2 - 20, 0)
        return min(abs(value), limit) * (value < 0 ? -1 : 1)
    }
}

private enum WorkflowGraphStyle {
    static func canvasBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.055, green: 0.066, blue: 0.105)
            : Color(red: 0.965, green: 0.972, blue: 0.985)
    }

    static func canvasBorder(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.08)
    }

    static func inactiveEdge(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.18)
    }

    static func secondaryFill(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.black.opacity(0.16) : Color.white.opacity(0.72)
    }

    static func mutedText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.34) : Color.black.opacity(0.42)
    }

    static func color(for status: DeliveryWorkflowNodeStatus, scheme: ColorScheme = .dark) -> Color {
        switch status {
        case .completed:
            return Color(red: 0.18, green: 0.78, blue: 0.31)
        case .failed:
            return Color(red: 0.92, green: 0.22, blue: 0.19)
        case .blocked, .awaitingUserInput:
            return Color(red: 0.95, green: 0.66, blue: 0.16)
        case .running:
            return Color.accentColor
        case .pending, .notStarted:
            return scheme == .dark ? Color.white.opacity(0.32) : Color.black.opacity(0.38)
        }
    }
}

private struct WorkflowGraphEdges: View {
    @Environment(\.colorScheme) private var colorScheme

    let phases: [DeliveryWorkflowPhase]
    let currentStep: String
    let nodeFrames: [String: CGRect]

    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                for edge in edges {
                    draw(edge, in: &context)
                }
            }
            ForEach(loopEdgesWithBadges) { edge in
                let iteration = edge.iteration ?? 1
                Text("\(iteration)")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(edgeColor(edge), in: Circle())
                    .position(labelPosition(for: edge))
                    .help("第 \(iteration) 轮")
            }
        }
    }

    private var edges: [WorkflowGraphEdge] {
        [
            WorkflowGraphEdge(from: "prd", to: "prd_review", isLoop: false, iteration: nil),
            WorkflowGraphEdge(from: "prd_review", to: "development", isLoop: false, iteration: nil),
            WorkflowGraphEdge(from: "development", to: "coding", isLoop: false, iteration: nil),
            WorkflowGraphEdge(from: "coding", to: "code_review", isLoop: false, iteration: nil),
            WorkflowGraphEdge(from: "code_review", to: "summary", isLoop: false, iteration: nil),
            WorkflowGraphEdge(from: "prd_review", to: "prd", isLoop: true, iteration: prdLoopIteration),
            WorkflowGraphEdge(from: "code_review", to: "coding", isLoop: true, iteration: codeLoopIteration),
        ]
    }

    private var loopEdgesWithBadges: [WorkflowGraphEdge] {
        edges.filter { $0.isLoop && ($0.iteration ?? 1) > 1 }
    }

    private var prdLoopIteration: Int? {
        let value = max(round(for: "prd"), round(for: "prd_review"))
        return value > 1 ? value : nil
    }

    private var codeLoopIteration: Int? {
        let value = max(round(for: "coding"), round(for: "code_review"))
        return value > 1 ? value : nil
    }

    private func round(for stage: String) -> Int {
        guard let title = phase(stage)?.title else { return 1 }
        return Self.roundNumber(in: title) ?? 1
    }

    private func phase(_ stage: String) -> DeliveryWorkflowPhase? {
        phases.first { $0.stage == stage }
    }

    private static func roundNumber(in text: String) -> Int? {
        let pattern = #"第\s*([0-9]+)\s*轮"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return Int(text[range])
    }

    private func draw(_ edge: WorkflowGraphEdge, in context: inout GraphicsContext) {
        guard phase(edge.from) != nil, phase(edge.to) != nil else { return }
        let color = edgeColor(edge)
        let path = path(for: edge)
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: edge.isLoop ? 1.7 : 1.9, lineCap: .round, dash: [4, 4]))
        drawArrow(for: edge, color: color, in: &context)
    }

    private func path(for edge: WorkflowGraphEdge) -> Path {
        let from = nodeFrames.frame(for: edge.from)
        let to = nodeFrames.frame(for: edge.to)
        var path = Path()
        if edge.isLoop && edge.from == "prd_review" {
            let endOffset = to.limitedHorizontalOffset(28)
            path.move(to: from.topMid)
            path.addQuadCurve(
                to: to.topPoint(offsetX: endOffset),
                control: CGPoint(x: (from.midX + to.midX) / 2, y: from.minY - 32)
            )
        } else if edge.isLoop && edge.from == "code_review" {
            let startOffset = from.limitedHorizontalOffset(42)
            let endOffset = to.limitedHorizontalOffset(-36)
            path.move(to: from.topPoint(offsetX: startOffset))
            path.addQuadCurve(
                to: to.bottomPoint(offsetX: endOffset),
                control: CGPoint(x: max(from.maxX, to.maxX) + 84, y: (from.midY + to.midY) / 2)
            )
        } else if edge.from == "coding" && edge.to == "code_review" {
            path.move(to: from.bottomMid)
            path.addQuadCurve(
                to: to.rightMid,
                control: CGPoint(x: max(from.maxX, to.maxX) + 54, y: (from.midY + to.midY) / 2)
            )
        } else {
            path.move(to: mainStart(edge))
            path.addQuadCurve(
                to: mainEnd(edge),
                control: mainControl(edge)
            )
        }
        return path
    }

    private func drawArrow(for edge: WorkflowGraphEdge, color: Color, in context: inout GraphicsContext) {
        let target = arrowTarget(edge)
        let point = target.point
        let angle = target.angle

        var arrow = Path()
        let size: CGFloat = 11
        arrow.move(to: point)
        arrow.addLine(to: CGPoint(x: point.x - cos(angle - .pi / 6) * size, y: point.y - sin(angle - .pi / 6) * size))
        arrow.addLine(to: CGPoint(x: point.x - cos(angle + .pi / 6) * size, y: point.y - sin(angle + .pi / 6) * size))
        arrow.closeSubpath()
        context.fill(arrow, with: .color(color))
    }

    private func mainStart(_ edge: WorkflowGraphEdge) -> CGPoint {
        let from = nodeFrames.frame(for: edge.from)
        if edge.from == "code_review" && edge.to == "summary" {
            return from.leftMid
        }
        return from.rightMid
    }

    private func mainEnd(_ edge: WorkflowGraphEdge) -> CGPoint {
        let to = nodeFrames.frame(for: edge.to)
        if edge.from == "code_review" && edge.to == "summary" {
            return to.rightMid
        }
        return to.leftMid
    }

    private func mainControl(_ edge: WorkflowGraphEdge) -> CGPoint {
        let start = mainStart(edge)
        let end = mainEnd(edge)
        if edge.from == "code_review" && edge.to == "summary" {
            return CGPoint(x: (start.x + end.x) / 2, y: start.y + 24)
        }
        return CGPoint(x: (start.x + end.x) / 2, y: min(start.y, end.y) - 24)
    }

    private func arrowTarget(_ edge: WorkflowGraphEdge) -> (point: CGPoint, angle: CGFloat) {
        if edge.isLoop && edge.from == "prd_review" {
            let to = nodeFrames.frame(for: edge.to)
            let point = to.topPoint(offsetX: to.limitedHorizontalOffset(28))
            return (point, .pi)
        }
        if edge.isLoop && edge.from == "code_review" {
            let to = nodeFrames.frame(for: edge.to)
            let point = to.bottomPoint(offsetX: to.limitedHorizontalOffset(-36))
            return (point, -.pi / 2)
        }
        if edge.from == "coding" && edge.to == "code_review" {
            let point = nodeFrames.frame(for: edge.to).rightMid
            return (point, .pi)
        }
        let end = mainEnd(edge)
        let control = mainControl(edge)
        let angle = atan2(end.y - control.y, end.x - control.x)
        return (end, angle)
    }

    private func labelPosition(for edge: WorkflowGraphEdge) -> CGPoint {
        if edge.from == "prd_review" {
            let from = nodeFrames.frame(for: edge.from)
            let to = nodeFrames.frame(for: edge.to)
            return CGPoint(x: (from.midX + to.midX) / 2, y: min(from.minY, to.minY) - 22)
        }
        let from = nodeFrames.frame(for: edge.from)
        let to = nodeFrames.frame(for: edge.to)
        return CGPoint(x: max(from.maxX, to.maxX) + 42, y: (from.midY + to.midY) / 2)
    }

    private func edgeColor(_ edge: WorkflowGraphEdge) -> Color {
        if edge.isLoop && (edge.iteration ?? 1) > 1 {
            return color(for: edge.to).opacity(0.9)
        }
        if edge.from == currentStep || edge.to == currentStep {
            return color(for: edge.to).opacity(0.92)
        }
        if phase(edge.from)?.status == .completed {
            return color(for: edge.from).opacity(0.78)
        }
        return WorkflowGraphStyle.inactiveEdge(for: colorScheme)
    }

    private func color(for stage: String) -> Color {
        WorkflowGraphStyle.color(for: phase(stage)?.status ?? .pending, scheme: colorScheme)
    }
}

private struct WorkflowGraphEdge: Identifiable {
    let from: String
    let to: String
    let isLoop: Bool
    let iteration: Int?

    var id: String {
        "\(from)-\(to)-\(isLoop ? "loop" : "main")"
    }
}

private struct WorkflowNodeView: View {
    @Environment(\.colorScheme) private var colorScheme

    let phase: DeliveryWorkflowPhase
    let isCurrent: Bool
    let artifactSummary: String
    let hasArtifactFile: Bool
    let onSelect: () -> Void
    let onOpenArtifact: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 7) {
                Circle()
                    .fill(nodeColor)
                    .frame(width: 7, height: 7)
                Text(ProjectWorkflowStatusPresentation.label(for: phase.status))
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(nodeColor.opacity(0.92))
            }
            Text(displayTitle)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(nodeColor.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            Button(action: onOpenArtifact) {
                Text(artifactSummary)
                    .font(.caption2)
                    .foregroundColor(hasArtifactFile ? nodeColor.opacity(0.86) : WorkflowGraphStyle.mutedText(for: colorScheme))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .disabled(!hasArtifactFile)
            .help(hasArtifactFile ? "打开 \(artifactSummary)" : "暂无可预览文件")
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            nodeColor.opacity(isCurrent ? 0.2 : 0.12),
                            WorkflowGraphStyle.secondaryFill(for: colorScheme),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    nodeColor.opacity(isCurrent ? 1 : 0.82),
                    lineWidth: isCurrent ? 2 : 1
                )
        )
        .shadow(color: nodeColor.opacity(isCurrent ? 0.28 : 0.12), radius: isCurrent ? 8 : 3, x: 0, y: 0)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .help("查看 \(phase.title) 对应阶段")
    }

    private var nodeColor: Color {
        WorkflowGraphStyle.color(for: phase.status, scheme: colorScheme)
    }

    private var displayTitle: String {
        ProjectWorkflowStatusPresentation.overviewTitle(for: phase.stage)
    }
}
