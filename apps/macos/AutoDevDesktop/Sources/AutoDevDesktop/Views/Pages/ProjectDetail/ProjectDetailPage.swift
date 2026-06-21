import SwiftUI

struct ProjectDetailPage: View {
    @ObservedObject var viewModel: ShellViewModel

    var body: some View {
        Group {
            if let project = viewModel.state.selectedProject {
                let detail = viewModel.state.selectedExecutionDetail

                VStack(spacing: AutoDevViewTheme.pageSpacing) {
                    ProjectWorkflowActionBar(
                        viewModel: viewModel,
                        snapshot: viewModel.state.selectedWorkflowSnapshot
                    )

                    ProjectWorkflowOverviewSection(
                        viewModel: viewModel,
                        snapshot: viewModel.state.selectedWorkflowSnapshot,
                        detail: detail
                    )

                    ProjectCurrentAgentSection(
                        snapshot: viewModel.state.selectedWorkflowSnapshot,
                        detail: detail,
                        projectName: project.title
                    )
                }
            } else {
                DashboardCard(title: "阶段详情") {
                    Text("对象不存在或已删除。")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

private struct ProjectWorkflowActionBar: View {
    @ObservedObject var viewModel: ShellViewModel
    let snapshot: DeliveryWorkflowSnapshot?

    var body: some View {
        HStack(spacing: 8) {
            Spacer()
            Button {
                viewModel.runSelectedWorkflowStep()
            } label: {
                Label(runTitle, systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)

            Button {
                viewModel.skipSelectedWorkflowStep()
            } label: {
                Label("跳过", systemImage: "forward.end.fill")
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var runTitle: String {
        switch snapshot?.status ?? .notStarted {
        case .failed, .blocked, .awaitingUserInput:
            return "重试"
        case .notStarted, .pending:
            return "开始执行"
        case .running, .completed:
            return "重新执行"
        }
    }
}

struct ProjectDetailDecisionFallbackSection: View {
    @ObservedObject var viewModel: ShellViewModel

    var body: some View {
        DashboardCard(title: "决策条") {
            VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
                HStack(alignment: .top, spacing: 12) {
                    MetricPill(title: "阶段", value: viewModel.state.activeDetailStage.rawValue)
                    MetricPill(title: "状态", value: viewModel.state.selectedProject?.status.rawValue ?? "-", valueColor: .secondary)
                    MetricPill(title: "更新时间", value: viewModel.state.selectedProject?.updateTime ?? "刚刚")
                    Spacer()
                    if viewModel.state.selectedProject?.status != .completed {
                        ProjectDetailFallbackActionCluster(
                            viewModel: viewModel,
                            primaryAction: viewModel.state.selectedStagePrimaryAction,
                            secondaryActions: viewModel.state.selectedStageSecondaryActions
                        )
                    }
                }
                Text(viewModel.state.selectedDetailDecisionQuestion)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct ProjectDetailFallbackActionCluster: View {
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
