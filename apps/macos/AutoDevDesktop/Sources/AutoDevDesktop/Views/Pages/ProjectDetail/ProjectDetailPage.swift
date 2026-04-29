import SwiftUI

struct ProjectDetailPage: View {
    @ObservedObject var viewModel: ShellViewModel

    var body: some View {
        Group {
            if let project = viewModel.state.selectedProject {
                let detail = viewModel.state.selectedExecutionDetail
                let subSteps = detail?.subSteps ?? []
                let activeSubStep = resolvedActiveSubStep(detail: detail, subSteps: subSteps) ?? ""

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
                                    onSelect: { viewModel.selectSubStep($0) },
                                    isStepDisabled: { step in
                                        isSubStepDisabled(step, detail: detail)
                                    },
                                    onDisabledSelect: { _ in
                                        viewModel.showStatusMessage("请先完成页面地图")
                                    }
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
        let detail = viewModel.state.selectedExecutionDetail
        let subSteps = detail?.subSteps ?? []
        let subStep = resolvedActiveSubStep(detail: detail, subSteps: subSteps)
        if let subStep,
           let match = subSteps.first(where: { $0.key == subStep }) {
            return "\(stage.rawValue) · \(match.label)"
        }
        return stage.rawValue
    }

    func resolvedActiveSubStep(
        detail: DeliveryExecutionDetail?,
        subSteps: [DeliverySubStepItem]
    ) -> String? {
        let stage = viewModel.state.activeDetailStage
        let selected = viewModel.state.selectedSubStep

        guard stage == .ui else {
            return selected ?? detail?.activeSubStep ?? subSteps.first?.key
        }

        let pageMapDone = subSteps.first(where: { $0.key == "page_map" })?.hasContent == true
        let interactionDone = subSteps.first(where: { $0.key == "interaction" })?.hasContent == true

        if !pageMapDone {
            return "page_map"
        }

        if !interactionDone {
            return "interaction"
        }

        if let selected,
           let selectedStep = subSteps.first(where: { $0.key == selected }),
           !isSubStepDisabled(selectedStep, detail: detail) {
            return selected
        }

        return detail?.activeSubStep ?? "interaction"
    }

    func isSubStepDisabled(_ step: DeliverySubStepItem, detail: DeliveryExecutionDetail?) -> Bool {
        guard viewModel.state.activeDetailStage == .ui else {
            return false
        }
        guard step.key == "interaction" else {
            return false
        }
        let pageMapDone = detail?.subSteps.first(where: { $0.key == "page_map" })?.hasContent == true
        return !pageMapDone
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
