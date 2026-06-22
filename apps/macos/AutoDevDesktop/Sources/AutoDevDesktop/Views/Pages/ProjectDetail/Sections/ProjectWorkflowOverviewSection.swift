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
                        hasArtifactFile: phase.filePath?.isEmpty == false,
                        onSelect: {
                            viewModel.selectDetailStage(lifecycleStage(for: phase.stage))
                        },
                        onOpenArtifact: {
                            openArtifact(for: phase)
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
        return "当前步骤：\(title(for: snapshot.currentStep)) · \(ProjectWorkflowStatusPresentation.label(for: snapshot.status))"
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

private struct WorkflowNodeView: View {
    let phase: DeliveryWorkflowPhase
    let isCurrent: Bool
    let artifactSummary: String
    let hasArtifactFile: Bool
    let onSelect: () -> Void
    let onOpenArtifact: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(ProjectWorkflowStatusPresentation.color(for: phase.status))
                    .frame(width: 9, height: 9)
                Text(ProjectWorkflowStatusPresentation.label(for: phase.status))
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(ProjectWorkflowStatusPresentation.color(for: phase.status))
            }
            Text(phase.title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
            Button(action: onOpenArtifact) {
                HStack(spacing: 4) {
                    Image(systemName: phase.artifactID == nil ? "doc" : "doc.fill")
                        .font(.caption2)
                    Text(artifactSummary)
                        .font(.caption2)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(hasArtifactFile ? .accentColor : .secondary)
            .disabled(!hasArtifactFile)
            .help(hasArtifactFile ? "打开 \(artifactSummary)" : "暂无可预览文件")
        }
        .frame(width: 172, height: 92, alignment: .topLeading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(ProjectWorkflowStatusPresentation.color(for: phase.status).opacity(isCurrent ? 0.14 : 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    isCurrent ? ProjectWorkflowStatusPresentation.color(for: phase.status).opacity(0.75) : Color.secondary.opacity(0.18),
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
