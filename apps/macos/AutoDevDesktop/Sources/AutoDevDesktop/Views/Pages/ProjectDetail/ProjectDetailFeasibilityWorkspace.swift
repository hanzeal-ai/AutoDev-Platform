import SwiftUI

extension ProjectDetailPage {
    func feasibilityWorkspace(project: DeliveryProjectItem, detail: DeliveryExecutionDetail?) -> some View {
        let draft = viewModel.state.selectedFeasibilityDraft
        let reportDownloads = stageDownloads(in: [.stageSnapshot])
        let materialDownloads = stageDownloads(in: [.rawInput])
        let hasJudgement = !(draft?.coreCapabilities.isEmpty ?? true)
            || !(draft?.risksAndConstraints.isEmpty ?? true)
            || !(draft?.initialDeliveryPlan.isEmpty ?? true)
            || !(detail?.stepProgress.isEmpty ?? true)

        return VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
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

            stageModule("可行性报告", when: AutoDevTextSupport.compactItems([draft?.feasibilityConclusion, detail?.objective]).first != nil || !reportDownloads.isEmpty) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    if let summary = AutoDevTextSupport.compactItems([draft?.feasibilityConclusion, detail?.objective]).first {
                        Text(summary)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if !reportDownloads.isEmpty {
                        HStack(spacing: 12) {
                            MetricPill(title: "版本", value: viewModel.state.selectedFeasibilityReportVersion)
                            MetricPill(title: "更新时间", value: viewModel.state.selectedFeasibilityReportUpdatedAt)
                        }
                        StageDownloadListView(viewModel: viewModel, items: reportDownloads)
                    }
                }
            }

            stageModule("参考资料与关键判断", when: hasJudgement || !materialDownloads.isEmpty) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
                    StageDownloadListView(viewModel: viewModel, items: materialDownloads)
                    StageLabeledListView(title: "核心能力", items: draft?.coreCapabilities ?? [])
                    StageLabeledListView(title: "主要风险与约束", items: draft?.risksAndConstraints ?? [])
                    StageLabeledListView(title: "初步交付建议", items: draft?.initialDeliveryPlan ?? [])
                    StageLabeledListView(title: "待确认事项", items: detail?.stepProgress.map(\.title) ?? [])
                }
            }
        }
    }
}
