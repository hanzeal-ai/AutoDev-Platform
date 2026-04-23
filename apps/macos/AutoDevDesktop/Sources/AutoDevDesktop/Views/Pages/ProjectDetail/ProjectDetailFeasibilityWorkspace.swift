import SwiftUI

extension ProjectDetailPage {
    func feasibilityWorkspace(project: DeliveryProjectItem, detail: DeliveryExecutionDetail?) -> some View {
        let draft = viewModel.state.selectedFeasibilityDraft
        let allDownloads = stageDownloads(in: [.stageSnapshot, .rawInput, .auditArchive])
        let artifacts = detail?.outputArtifacts ?? []
        let hasJudgement = !(draft?.coreCapabilities.isEmpty ?? true)
            || !(draft?.risksAndConstraints.isEmpty ?? true)
            || !(draft?.initialDeliveryPlan.isEmpty ?? true)

        return VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
            stageModule("进度轨迹", when: !(detail?.stepProgress.isEmpty ?? true)) {
                StageStepProgressBar(steps: detail?.stepProgress ?? [])
            }

            stageModule("项目简介", when: true) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    KeyValueRow(key: "项目名称", value: draft?.projectName ?? project.title)
                    if let summary = AutoDevTextSupport.value(for: "一句话概述", in: detail?.inputContexts ?? []) {
                        KeyValueRow(key: "一句话概述", value: summary)
                    }
                    if let problem = draft?.problemDefinition ?? AutoDevTextSupport.value(for: "问题定义", in: detail?.inputContexts ?? []) {
                        KeyValueRow(key: "问题定义", value: problem)
                    }
                    if let users = draft?.targetUsers ?? AutoDevTextSupport.value(for: "目标用户", in: detail?.inputContexts ?? []) {
                        KeyValueRow(key: "目标用户", value: users)
                    }
                    if let conclusion = draft?.feasibilityConclusion ?? AutoDevTextSupport.value(for: "当前立项结论", in: detail?.inputContexts ?? []) {
                        KeyValueRow(key: "当前立项结论", value: conclusion)
                    }
                }
            }

            stageModule("可行性判断", when: hasJudgement) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
                    StageLabeledListView(title: "核心能力", items: draft?.coreCapabilities ?? [])
                    StageLabeledListView(title: "主要风险与约束", items: draft?.risksAndConstraints ?? [])
                    StageLabeledListView(title: "初步交付建议", items: draft?.initialDeliveryPlan ?? [])
                }
            }

            stageModule("阶段产物", when: !artifacts.isEmpty || !allDownloads.isEmpty) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    HStack(spacing: 12) {
                        MetricPill(title: "版本", value: viewModel.state.selectedFeasibilityReportVersion)
                        MetricPill(title: "更新时间", value: viewModel.state.selectedFeasibilityReportUpdatedAt)
                    }
                    if !artifacts.isEmpty {
                        StageArtifactListView(viewModel: viewModel, items: artifacts)
                    }
                    StageDownloadListView(viewModel: viewModel, items: allDownloads)
                }
            }
        }
    }
}
