import SwiftUI

struct ProjectWorkflowOverviewSection: View {
    @ObservedObject var viewModel: ShellViewModel
    let snapshot: DeliveryWorkflowSnapshot?
    let detail: DeliveryExecutionDetail?

    var body: some View {
        DashboardCard(title: "Workflow 总览") {
            VStack(alignment: .leading, spacing: 14) {
                header
                workflowTrack
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot?.projectName.isEmpty == false ? snapshot?.projectName ?? "项目" : "项目")
                    .font(.subheadline.weight(.semibold))
                Text(statusLine)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button {
                Task { await viewModel.refreshSelectedProjectDetail() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("刷新 Workflow 状态")
        }
    }

    private var workflowTrack: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(phases.enumerated()), id: \.element.id) { index, phase in
                    WorkflowNodeView(
                        phase: phase,
                        isCurrent: phase.stage == snapshot?.currentStep,
                        artifactSummary: artifactSummary(for: phase),
                        onSelect: {
                            viewModel.selectDetailStage(lifecycleStage(for: phase.stage))
                        }
                    )
                    if index < phases.count - 1 {
                        let next = phases[index + 1]
                        WorkflowConnectorView(
                            isComplete: phase.status == .completed,
                            isActive: phase.stage == snapshot?.currentStep || next.stage == snapshot?.currentStep
                        )
                    }
                }
            }
            .padding(.vertical, 2)
        }
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
                artifactID: nil
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
        return "当前步骤：\(title(for: snapshot.currentStep)) · \(label(for: snapshot.status))"
    }

    private func title(for stage: String) -> String {
        phases.first(where: { $0.stage == stage })?.title ?? fallbackTitle(for: stage)
    }

    private func fallbackTitle(for stage: String) -> String {
        switch stage {
        case "chat": return "需求澄清"
        case "report": return "可行性报告"
        case "prd": return "PRD"
        case "prd_review": return "需求评审"
        case "development": return "研发计划"
        case "coding": return "编码"
        case "code_review": return "代码评审"
        case "summary": return "总结"
        default: return stage
        }
    }

    private func lifecycleStage(for workflowStage: String) -> DeliveryLifecycleStage {
        switch workflowStage {
        case "chat", "report":
            return .feasibility
        case "prd", "prd_review":
            return .prd
        default:
            return .development
        }
    }

    private func artifactSummary(for phase: DeliveryWorkflowPhase) -> String {
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

    private var currentDetailFileNames: [String] {
        let unitNames = (detail?.workUnits ?? []).map(\.title).filter { !$0.isEmpty }
        if !unitNames.isEmpty {
            return Array(unitNames.prefix(3))
        }
        let stepNames = (detail?.stepProgress ?? []).map(\.title).filter { !$0.isEmpty }
        return Array(stepNames.prefix(3))
    }
}

struct ProjectCurrentAgentSection: View {
    let snapshot: DeliveryWorkflowSnapshot?
    let detail: DeliveryExecutionDetail?
    let projectName: String

    var body: some View {
        DashboardCard(title: "当前 Agent 执行") {
            VStack(alignment: .leading, spacing: 14) {
                header
                Divider()
                content
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(agentTitle)
                    .font(.subheadline.weight(.semibold))
                Text(projectName.isEmpty ? "当前项目" : projectName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            HStack(spacing: 6) {
                Circle()
                    .fill(color(for: snapshot?.status ?? .pending))
                    .frame(width: 8, height: 8)
                Text(label(for: snapshot?.status ?? .pending))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(color(for: snapshot?.status ?? .pending))
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let snapshot {
            primaryContent(for: snapshot)
            issueReasonList
        } else {
            AgentNoticeLine(systemImage: "clock", title: "正在读取状态", detail: "等待 Workflow 状态返回。")
        }
    }

    @ViewBuilder
    private func primaryContent(for snapshot: DeliveryWorkflowSnapshot) -> some View {
        if snapshot.status == .failed, let error = snapshot.error, !error.isEmpty {
            AgentNoticeLine(systemImage: "exclamationmark.triangle.fill", title: "执行失败", detail: error)
        } else if snapshot.status == .blocked {
            AgentNoticeLine(systemImage: "pause.circle.fill", title: "流程阻塞", detail: latestDetail(fallback: "等待人工确认或补充处理。"))
        } else if snapshot.currentStep == "coding", !fileNames.isEmpty {
            fileSummary
            executionEvents
        } else {
            stageSummary
            executionEvents
            stepList
        }
    }

    private var fileSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("已创建/更改 \(fileNames.count) 个文件")
                .font(.subheadline.weight(.semibold))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(fileNames, id: \.self) { name in
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                        Text(name)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
        }
    }

    @ViewBuilder
    private var stageSummary: some View {
        if let detail, !detail.objective.isEmpty {
            AgentNoticeLine(systemImage: "text.alignleft", title: "阶段摘要", detail: detail.objective)
        } else {
            AgentNoticeLine(systemImage: "sparkles", title: "执行状态", detail: latestDetail(fallback: "等待当前 Agent 输出。"))
        }
    }

    @ViewBuilder
    private var executionEvents: some View {
        let events = currentEvents
        if !events.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("执行过程")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                ForEach(events) { event in
                    AgentTimelineRow(event: event)
                }
            }
        }
    }

    @ViewBuilder
    private var stepList: some View {
        let steps = detail?.stepProgress ?? []
        if !steps.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("当前步骤")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                ForEach(steps.prefix(8)) { step in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(step.status == .completed ? Color.green : Color.accentColor)
                            .frame(width: 7, height: 7)
                        Text(step.title)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var issueReasonList: some View {
        let reasons = issueReasons
        if !reasons.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("异常原因")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                ForEach(reasons) { reason in
                    AgentNoticeLine(
                        systemImage: reason.status == .failed ? "exclamationmark.triangle.fill" : "pause.circle.fill",
                        title: "\(stageTitle(for: reason.stage)) · \(label(for: reason.status))",
                        detail: reason.detail
                    )
                }
            }
        }
    }

    private var agentTitle: String {
        "\(stageTitle(for: snapshot?.currentStep ?? "not_started")) Agent"
    }

    private var fileNames: [String] {
        let unitNames = (detail?.workUnits ?? []).map(\.title).filter { !$0.isEmpty }
        if !unitNames.isEmpty {
            return Array(unitNames.prefix(12))
        }
        let stepNames = (detail?.stepProgress ?? []).map(\.title).filter { !$0.isEmpty }
        return Array(stepNames.prefix(12))
    }

    private var currentEvents: [DeliveryWorkflowEventItem] {
        guard let snapshot else { return [] }
        let latest = snapshot.events
            .filter { $0.stage == snapshot.currentStep && $0.type == "log" }
            .sorted { $0.sequence > $1.sequence }
            .prefix(5)
        return Array(latest.reversed())
    }

    private var issueReasons: [WorkflowIssueReason] {
        guard let snapshot else { return [] }
        var seen = Set<String>()
        return snapshot.events
            .filter { $0.status == .failed || $0.status == .blocked }
            .sorted { $0.sequence < $1.sequence }
            .compactMap { event in
                let detail = event.detail.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !detail.isEmpty else { return nil }
                let key = "\(event.stage)|\(event.status.rawValue)|\(detail)"
                guard seen.insert(key).inserted else { return nil }
                return WorkflowIssueReason(stage: event.stage, status: event.status, detail: detail)
            }
    }

    private func latestDetail(fallback: String) -> String {
        currentEvents.last?.detail ?? fallback
    }

    private func stageTitle(for stage: String) -> String {
        switch stage {
        case "chat": return "需求澄清"
        case "report": return "可行性分析"
        case "prd": return "产品需求"
        case "prd_review": return "需求评审"
        case "development": return "研发规划"
        case "coding": return "代码生成"
        case "code_review": return "代码评审"
        case "summary": return "项目总结"
        default: return "Workflow"
        }
    }
}

private struct WorkflowIssueReason: Identifiable {
    let stage: String
    let status: DeliveryWorkflowNodeStatus
    let detail: String

    var id: String {
        "\(stage)-\(status.rawValue)-\(detail)"
    }
}

private struct AgentNoticeLine: View {
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: systemImage)
                .foregroundColor(.accentColor)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct AgentTimelineRow: View {
    let event: DeliveryWorkflowEventItem

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(color(for: event.status))
                .frame(width: 7, height: 7)
                .padding(.top, 5)
            Text(event.detail)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct WorkflowNodeView: View {
    let phase: DeliveryWorkflowPhase
    let isCurrent: Bool
    let artifactSummary: String
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color(for: phase.status))
                    .frame(width: 9, height: 9)
                Text(label(for: phase.status))
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(color(for: phase.status))
            }
            Text(phase.title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
            HStack(spacing: 4) {
                Image(systemName: phase.artifactID == nil ? "doc" : "doc.fill")
                    .font(.caption2)
                Text(artifactSummary)
                    .font(.caption2)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .foregroundColor(.secondary)
        }
        .frame(width: 172, height: 92, alignment: .topLeading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color(for: phase.status).opacity(isCurrent ? 0.14 : 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    isCurrent ? color(for: phase.status).opacity(0.75) : Color.secondary.opacity(0.18),
                    lineWidth: isCurrent ? 1.5 : 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .help("查看 \(phase.title) 对应阶段")
    }
}

private struct WorkflowConnectorView: View {
    let isComplete: Bool
    let isActive: Bool

    var body: some View {
        Capsule(style: .continuous)
            .fill(connectorColor)
            .frame(width: 46, height: 3)
            .padding(.horizontal, 7)
            .frame(width: 60, height: 92)
    }

    private var connectorColor: Color {
        if isComplete {
            return Color.green.opacity(0.75)
        }
        if isActive {
            return Color.accentColor.opacity(0.55)
        }
        return Color.secondary.opacity(0.25)
    }
}

private func color(for status: DeliveryWorkflowNodeStatus) -> Color {
    switch status {
    case .completed:
        return .green
    case .running:
        return .accentColor
    case .failed:
        return .red
    case .blocked:
        return .orange
    case .awaitingUserInput:
        return .purple
    case .notStarted, .pending:
        return .secondary
    }
}

private func label(for status: DeliveryWorkflowNodeStatus) -> String {
    switch status {
    case .notStarted:
        return "未开始"
    case .pending:
        return "等待"
    case .running:
        return "执行中"
    case .completed:
        return "完成"
    case .failed:
        return "失败"
    case .blocked:
        return "阻塞"
    case .awaitingUserInput:
        return "待补充"
    }
}
