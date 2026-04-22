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
                            if let detail = viewModel.state.selectedExecutionDetail {
                                detailStageWorkspace(project: project, detail: detail)
                            } else {
                                ProjectDetailFallbackWorkspace(viewModel: viewModel, project: project)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                    } else {
                        HStack(alignment: .top, spacing: AutoDevViewTheme.pageSpacing) {
                            DashboardCard(title: "当前阶段工作区") {
                                if let detail = viewModel.state.selectedExecutionDetail {
                                    detailStageWorkspace(project: project, detail: detail)
                                } else {
                                    ProjectDetailFallbackWorkspace(viewModel: viewModel, project: project)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .top)

                            VStack(spacing: AutoDevViewTheme.pageSpacing) {
                                if let detail = viewModel.state.selectedExecutionDetail {
                                    ProjectDetailRiskSection(detail: detail)
                                    ProjectDetailEventSection(detail: detail)
                                } else {
                                    ProjectDetailFallbackSidebar(viewModel: viewModel)
                                }
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
                    ProjectDetailFallbackActionCluster(
                        viewModel: viewModel,
                        primaryAction: viewModel.state.selectedStagePrimaryAction,
                        secondaryActions: viewModel.state.selectedStageSecondaryActions
                    )
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

struct ProjectDetailFallbackWorkspace: View {
    @ObservedObject var viewModel: ShellViewModel
    let project: DeliveryProjectItem

    var body: some View {
        let draft = viewModel.state.selectedFeasibilityDraft
        let downloads = viewModel.state.selectedStageDownloads
        let stage = viewModel.state.activeDetailStage

        return VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
            DashboardCard(title: "项目概览") {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    KeyValueRow(key: "项目名称", value: draft?.projectName ?? project.title)
                    KeyValueRow(key: "当前阶段", value: stage.rawValue)
                    KeyValueRow(key: "阶段状态", value: project.status.rawValue)
                    KeyValueRow(key: "阶段进度", value: "\(Int((project.progress * 100).rounded()))%")
                    if stage == .development {
                        KeyValueRow(key: "当前目标", value: "完成前后端需求分析、任务拆分、编码审查循环与稳定预览交付")
                    } else if !project.currentGoal.isEmpty {
                        KeyValueRow(key: "当前目标", value: project.currentGoal)
                    }
                    if stage == .development {
                        KeyValueRow(key: "下一步", value: "生成前后端任务拆分产物")
                    } else if !project.nextAction.isEmpty {
                        KeyValueRow(key: "下一步", value: project.nextAction)
                    }
                    if let blockReason = project.blockReason, !blockReason.isEmpty {
                        KeyValueRow(key: "阻塞原因", value: blockReason)
                    }
                }
            }

            if stage == .development {
                ProjectDetailDevelopmentPlaceholder(viewModel: viewModel)
            } else {
                ProjectDetailFeasibilityFallbackContent(
                    viewModel: viewModel,
                    draft: draft,
                    downloads: downloads
                )
            }
        }
    }
}

private struct ProjectDetailDevelopmentPlaceholder: View {
    @ObservedObject var viewModel: ShellViewModel

    var body: some View {
        let units = DevelopmentWorkUnitPresenter.displayUnits(for: nil)
        return VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
            DashboardCard(title: "当前执行") {
                DevelopmentActiveUnitCard(
                    viewModel: viewModel,
                    unit: DevelopmentWorkUnitPresenter.activeUnit(in: units),
                    projectName: viewModel.state.selectedProject?.title ?? "项目"
                )
            }

            DashboardCard(title: "执行单元") {
                DevelopmentWorkUnitBoard(viewModel: viewModel, units: units)
            }
        }
    }
}

private struct ProjectDetailFeasibilityFallbackContent: View {
    @ObservedObject var viewModel: ShellViewModel
    let draft: FeasibilityReportDraft?
    let downloads: [StageDownloadItem]

    var body: some View {
        VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
            DashboardCard(title: "下一步指引") {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    Text("当前阶段详情还在加载中，先按阶段草稿推进下一步。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(alignment: .top, spacing: 12) {
                        MetricPill(title: "建议动作", value: viewModel.state.selectedStagePrimaryAction)
                        Spacer()
                    }

                    HStack(spacing: 8) {
                        Button(viewModel.state.selectedStagePrimaryAction) {
                            viewModel.triggerStageAction(viewModel.state.selectedStagePrimaryAction)
                        }
                        .buttonStyle(.borderedProminent)

                        ForEach(Array(viewModel.state.selectedStageSecondaryActions.enumerated()), id: \.offset) { _, action in
                            Button(action) {
                                viewModel.triggerStageAction(action)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            DashboardCard(title: "阶段资料预览与下载") {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    if let draft {
                        Text(draft.feasibilityConclusion)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .leading, spacing: 6) {
                            StageLabeledListView(title: "核心能力", items: draft.coreCapabilities)
                            StageLabeledListView(title: "风险与约束", items: draft.risksAndConstraints)
                            StageLabeledListView(title: "初步交付建议", items: draft.initialDeliveryPlan)
                        }
                    } else {
                        Text("可行性草稿尚未准备好。")
                            .foregroundColor(.secondary)
                    }

                    if let path = viewModel.state.selectedFeasibilityReportDownloadPath {
                        HStack(spacing: 8) {
                            Button("预览 / 下载报告") {
                                viewModel.openFeasibilityReportDownload()
                            }
                            .buttonStyle(.borderedProminent)

                            Text(URL(fileURLWithPath: path).lastPathComponent)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }

                    if !downloads.isEmpty {
                        StageDownloadListView(
                            viewModel: viewModel,
                            items: downloads.filter { $0.category == .stageSnapshot || $0.category == .rawInput }
                        )
                    }
                }
            }
        }
    }
}

struct ProjectDetailFallbackSidebar: View {
    @ObservedObject var viewModel: ShellViewModel

    var body: some View {
        VStack(spacing: AutoDevViewTheme.pageSpacing) {
            DashboardCard(title: "阶段提醒") {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    Text("当前详情尚未拉取到完整执行数据。")
                        .font(.subheadline)
                    Text("可先查看可行性报告预览，并通过下一步指引继续推进。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            DashboardCard(title: "报告状态") {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    MetricPill(
                        title: "版本",
                        value: viewModel.state.selectedFeasibilityReportVersion
                    )
                    MetricPill(
                        title: "更新时间",
                        value: viewModel.state.selectedFeasibilityReportUpdatedAt
                    )

                    if viewModel.state.selectedFeasibilityReportDownloadPath != nil {
                        Button("打开报告文件") {
                            viewModel.openFeasibilityReportDownload()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }
}
