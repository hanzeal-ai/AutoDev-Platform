import SwiftUI

extension ProjectDetailPage {
    func feasibilityWorkspace(project: DeliveryProjectItem, detail: DeliveryExecutionDetail?) -> some View {
        let activeSubStep = detail?.activeSubStep ?? viewModel.state.selectedSubStep ?? "clarification"

        return VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
            if activeSubStep == "report" {
                feasibilityReportContent(project: project, detail: detail)
            } else {
                feasibilityClarificationContent(project: project, detail: detail)
            }
        }
    }

    /// 需求澄清 — chat interface + basic project info
    @ViewBuilder
    private func feasibilityClarificationContent(project: DeliveryProjectItem, detail: DeliveryExecutionDetail?) -> some View {
        let draft = viewModel.state.selectedFeasibilityDraft

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
            }
        }

        stageModule("对话式澄清", when: true) {
            Text("通过对话帮助 AI 理解项目需求，完善可行性判断所需的输入。")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    /// 可行性报告 — structured analysis result
    @ViewBuilder
    private func feasibilityReportContent(project: DeliveryProjectItem, detail: DeliveryExecutionDetail?) -> some View {
        let draft = viewModel.state.selectedFeasibilityDraft
        let artifacts = detail?.outputArtifacts ?? []
        let allDownloads = stageDownloads(in: [.stageSnapshot, .rawInput, .auditArchive])
        let hasJudgement = !(draft?.coreCapabilities.isEmpty ?? true)
            || !(draft?.risksAndConstraints.isEmpty ?? true)
            || !(draft?.initialDeliveryPlan.isEmpty ?? true)
        let conclusion = draft?.feasibilityConclusion ?? AutoDevTextSupport.value(for: "当前立项结论", in: detail?.inputContexts ?? [])

        stageModule("立项结论", when: conclusion != nil) {
            if let conclusion {
                HStack(spacing: 8) {
                    Image(systemName: conclusionIcon(conclusion))
                        .foregroundColor(conclusionColor(conclusion))
                    Text(conclusion)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                }
            }
        }

        stageModule("可行性分析", when: hasJudgement) {
            VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
                StageLabeledListView(title: "核心能力", items: draft?.coreCapabilities ?? [])
                StageLabeledListView(title: "主要风险与约束", items: draft?.risksAndConstraints ?? [])
                StageLabeledListView(title: "初步交付建议", items: draft?.initialDeliveryPlan ?? [])
            }
        }

        stageModule("进度轨迹", when: !(detail?.stepProgress.isEmpty ?? true)) {
            StageStepProgressBar(steps: detail?.stepProgress ?? [])
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

    private func conclusionIcon(_ text: String) -> String {
        if text.contains("通过") || text.contains("可行") { return "checkmark.seal.fill" }
        if text.contains("不") || text.contains("否") { return "xmark.seal.fill" }
        return "questionmark.circle.fill"
    }

    private func conclusionColor(_ text: String) -> Color {
        if text.contains("通过") || text.contains("可行") { return .green }
        if text.contains("不") || text.contains("否") { return .red }
        return .orange
    }
}
