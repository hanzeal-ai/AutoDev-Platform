import SwiftUI

struct ProjectDetailDecisionSection: View {
    @ObservedObject var viewModel: ShellViewModel
    let detail: DeliveryExecutionDetail

    private var showActionButtons: Bool {
        guard detail.status != .completed else { return false }
        let stage = viewModel.state.activeDetailStage
        let config = viewModel.state.stageAutomation
        if !config.stageNeedsConfirmation(stage) {
            if let aiRun = detail.aiRun, aiRun.isActive {
                return false
            }
        }
        return true
    }

    var body: some View {
        DashboardCard(title: "决策条") {
            VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
                HStack(alignment: .top, spacing: 12) {
                    MetricPill(title: "阶段", value: viewModel.state.activeDetailStage.rawValue)
                    MetricPill(title: "状态", value: detail.status.rawValue, valueColor: detail.status.color)
                    MetricPill(title: "更新时间", value: detail.updatedAt)
                    Spacer()
                    if showActionButtons {
                        ProjectDetailActionCluster(
                            viewModel: viewModel,
                            primaryAction: viewModel.state.selectedStagePrimaryAction,
                            secondaryActions: viewModel.state.selectedStageSecondaryActions
                        )
                    } else if detail.status != .completed {
                        Text("自动推进中…")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Text(viewModel.state.selectedDetailDecisionQuestion)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct ProjectDetailActionCluster: View {
    @ObservedObject var viewModel: ShellViewModel
    let primaryAction: String
    let secondaryActions: [String]

    var body: some View {
        HStack(spacing: 6) {
            Button(primaryAction) {
                viewModel.triggerStageAction(primaryAction)
            }
            .buttonStyle(.borderedProminent)

            ForEach(Array(secondaryActions.enumerated()), id: \.offset) { _, action in
                Button(action) {
                    viewModel.triggerStageAction(action)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}
