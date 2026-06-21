import SwiftUI

struct ProjectWorkflowOverviewSection: View {
    @ObservedObject var viewModel: ShellViewModel
    let snapshot: DeliveryWorkflowSnapshot?
    let subSteps: [DeliverySubStepItem]
    let activeSubStep: String
    let isSubStepDisabled: (DeliverySubStepItem) -> Bool

    var body: some View {
        DashboardCard(title: "Workflow 总览") {
            VStack(alignment: .leading, spacing: 14) {
                header
                workflowTrack
                if !subSteps.isEmpty {
                    StageSubStepTrack(
                        subSteps: subSteps,
                        activeSubStep: activeSubStep,
                        onSelect: { viewModel.selectSubStep($0) },
                        isStepDisabled: isSubStepDisabled,
                        onDisabledSelect: { _ in
                            viewModel.showStatusMessage("请先完成页面地图")
                        }
                    )
                }
                if let snapshot, !snapshot.events.isEmpty {
                    eventStrip(snapshot.events)
                }
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

            if showResumeButton {
                Button {
                    viewModel.generateAIForSelectedStage()
                } label: {
                    Label(resumeButtonTitle, systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var workflowTrack: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(phases.enumerated()), id: \.element.id) { index, phase in
                    WorkflowNodeView(
                        phase: phase,
                        isCurrent: phase.stage == snapshot?.currentStep,
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

    private func eventStrip(_ events: [DeliveryWorkflowEventItem]) -> some View {
        let latest = Array(events.sorted { $0.sequence > $1.sequence }.prefix(4))
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(latest) { event in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(color(for: event.status))
                        .frame(width: 7, height: 7)
                        .padding(.top, 5)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Text(event.detail)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
            }
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

    private var showResumeButton: Bool {
        guard let snapshot else { return true }
        return snapshot.status != .completed && !snapshot.isActive
    }

    private var resumeButtonTitle: String {
        guard let snapshot else { return "开始执行" }
        switch snapshot.status {
        case .failed:
            return "重试"
        case .blocked, .awaitingUserInput:
            return "继续执行"
        case .notStarted, .pending:
            return "开始执行"
        default:
            return "继续执行"
        }
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
}

private struct WorkflowNodeView: View {
    let phase: DeliveryWorkflowPhase
    let isCurrent: Bool
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
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
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 4) {
                Image(systemName: phase.artifactID == nil ? "doc" : "doc.fill")
                    .font(.caption2)
                Text(phase.artifactID == nil ? "无产物" : "产物就绪")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
        }
        .frame(width: 132, height: 82, alignment: .topLeading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color(for: phase.status).opacity(isCurrent ? 0.14 : 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isCurrent ? color(for: phase.status).opacity(0.75) : Color.secondary.opacity(0.18), lineWidth: isCurrent ? 1.5 : 1)
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
        TimelineView(.animation) { context in
            let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.0)
            Capsule(style: .continuous)
                .stroke(
                    isComplete ? Color.green.opacity(0.75) : Color.secondary.opacity(0.25),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: isActive ? [7, 6] : [], dashPhase: isActive ? -phase * 26 : 0)
                )
                .frame(width: 44, height: 3)
                .padding(.horizontal, 6)
        }
        .frame(width: 56, height: 82)
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
