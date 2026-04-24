import SwiftUI

struct ProjectDetailPage: View {
    @ObservedObject var viewModel: ShellViewModel

    var body: some View {
        Group {
            if let project = viewModel.state.selectedProject {
                let detail = viewModel.state.selectedExecutionDetail
                let subSteps = detail?.subSteps ?? []
                let activeSubStep = detail?.activeSubStep ?? subSteps.first?.key ?? ""

                VStack(spacing: AutoDevViewTheme.pageSpacing) {
                    // Decision bar
                    if let detail {
                        ProjectDetailDecisionSection(viewModel: viewModel, detail: detail)
                    } else {
                        ProjectDetailDecisionFallbackSection(viewModel: viewModel)
                    }

                    // Lifecycle track + sub-step track
                    DashboardCard(title: "生命周期轨道") {
                        VStack(alignment: .leading, spacing: 10) {
                            ProjectDetailLifecycleTrack(
                                current: project.lifecycleStage,
                                viewing: viewModel.state.activeDetailStage,
                                onSelectStage: { viewModel.selectDetailStage($0) }
                            )
                            if !subSteps.isEmpty {
                                StageSubStepTrack(
                                    subSteps: subSteps,
                                    activeSubStep: activeSubStep,
                                    onSelect: { viewModel.selectSubStep($0) }
                                )
                            }
                        }
                    }

                    // AI execution progress (skip for feasibility chat)
                    if viewModel.state.activeDetailStage != .feasibility,
                       let detail
                    {
                        StageAIExecutionProgressView(
                            viewModel: viewModel,
                            stage: viewModel.state.activeDetailStage,
                            detail: detail,
                            downloads: viewModel.state.selectedStageDownloads
                        )
                    }

                    // Stage workspace — full width for all stages
                    DashboardCard(title: stageWorkspaceTitle) {
                        detailStageWorkspace(project: project, detail: detail)
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            } else {
                DashboardCard(title: "阶段详情") {
                    Text("对象不存在或已删除。")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var stageWorkspaceTitle: String {
        let stage = viewModel.state.activeDetailStage
        let subStep = viewModel.state.selectedSubStep
        let detail = viewModel.state.selectedExecutionDetail
        if let subStep,
           let match = detail?.subSteps.first(where: { $0.key == subStep }) {
            return "\(stage.rawValue) · \(match.label)"
        }
        return stage.rawValue
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
