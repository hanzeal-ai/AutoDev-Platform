import SwiftUI

struct ProjectDetailPage: View {
    @ObservedObject var viewModel: ShellViewModel

    var body: some View {
        Group {
            if let project = viewModel.state.selectedProject {
                VStack(spacing: AutoDevViewTheme.pageSpacing) {
                    if let detail = viewModel.state.selectedExecutionDetail {
                        ProjectDetailDecisionSection(viewModel: viewModel, detail: detail)
                    } else {
                        ProjectDetailDecisionFallbackSection(viewModel: viewModel)
                    }
                    ProjectDetailLifecycleSection(viewModel: viewModel)

                    if viewModel.state.activeDetailStage == .development {
                        DashboardCard(title: "当前阶段工作区") {
                            detailStageWorkspace(project: project, detail: viewModel.state.selectedExecutionDetail)
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                    } else {
                        if let detail = viewModel.state.selectedExecutionDetail {
                            HStack(alignment: .top, spacing: AutoDevViewTheme.pageSpacing) {
                                DashboardCard(title: "当前阶段工作区") {
                                    detailStageWorkspace(project: project, detail: detail)
                                }
                                .frame(maxWidth: .infinity, alignment: .top)

                                VStack(spacing: AutoDevViewTheme.pageSpacing) {
                                    ProjectDetailRiskSection(detail: detail)
                                    ProjectDetailEventSection(detail: detail)
                                }
                                .frame(maxWidth: .infinity, alignment: .top)
                            }
                        } else {
                            DashboardCard(title: "当前阶段工作区") {
                                detailStageWorkspace(project: project, detail: nil)
                            }
                            .frame(maxWidth: .infinity, alignment: .top)
                        }
                    }
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
