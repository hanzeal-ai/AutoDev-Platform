import SwiftUI

extension ProjectDetailPage {
    func developmentWorkspace(detail: DeliveryExecutionDetail?) -> some View {
        let lines = detail?.inputContexts ?? []
        let blueprint = viewModel.state.selectedStageBlueprint
        let outputs = detail?.outputArtifacts ?? []
        let workUnits = DevelopmentWorkUnitPresenter.displayUnits(for: detail)
        let activeUnit = DevelopmentWorkUnitPresenter.activeUnit(in: workUnits)
        let agentRules = AutoDevTextSupport.compactItems([
            AutoDevTextSupport.firstValue(in: lines, keys: ["单前端 Agent", "前端 Agent", "前端执行 Agent"]).map { "单前端 Agent：\($0)" },
            AutoDevTextSupport.firstValue(in: lines, keys: ["单后端 Agent", "后端 Agent", "后端执行 Agent"]).map { "单后端 Agent：\($0)" },
            AutoDevTextSupport.firstValue(in: lines, keys: ["Agent 编制", "Agent 配置", "Agent 分工"]).map { "Agent 编制：\($0)" },
        ])
        let modelRules = AutoDevTextSupport.compactItems([
            AutoDevTextSupport.firstValue(in: lines, keys: ["实现模型", "实现模型配置", "编码模型"]).map { "实现模型：\($0)" },
            AutoDevTextSupport.firstValue(in: lines, keys: ["Code Review 模型", "评审模型", "审查模型"]).map { "Code Review 模型：\($0)" },
        ])
        let branchRules = AutoDevTextSupport.compactItems([
            AutoDevTextSupport.firstValue(in: lines, keys: ["Git 分支", "开发分支", "工作分支"]).map { "Git 分支：\($0)" },
            AutoDevTextSupport.firstValue(in: lines, keys: ["稳定预览规则", "预览规则", "稳定预览"]).map { "稳定预览规则：\($0)" },
            AutoDevTextSupport.firstValue(in: lines, keys: ["编码循环", "开发循环", "交付循环"]).map { "编码循环：\($0)" },
        ])
        let blueprintOutputs = blueprint?.outputArtifacts ?? []
        let blueprintRisks = blueprint?.riskItems ?? []
        let downloads = stageDownloads(in: [.stageSnapshot, .auditArchive])

        return VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
            StageAIExecutionProgressView(
                viewModel: viewModel,
                stage: .development,
                detail: detail,
                downloads: downloads
            )

            VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
                stageModule("当前执行", when: activeUnit != nil) {
                    if let activeUnit {
                        DevelopmentActiveUnitCard(
                            viewModel: viewModel,
                            unit: activeUnit,
                            projectName: detail?.projectName ?? viewModel.state.selectedProject?.title ?? "项目"
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)

                stageModule("执行单元", when: !workUnits.isEmpty) {
                    DevelopmentWorkUnitBoard(viewModel: viewModel, units: workUnits)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            HStack(alignment: .top, spacing: AutoDevViewTheme.cardSpacing) {
                stageModule("阶段产物", when: true) {
                    VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                        if !blueprintOutputs.isEmpty {
                            StageLabeledListView(title: "蓝图预期产物", items: blueprintOutputs)
                        }
                        if !outputs.isEmpty {
                            StageArtifactListView(items: outputs)
                        }
                        if let blockerReason = detail?.blockerReason {
                            KeyValueRow(key: "阻塞原因", value: blockerReason)
                        }
                        if detail?.needsUserIntervention == true {
                            KeyValueRow(key: "人工介入", value: "需要")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)

                stageModule(
                    "开发编排",
                    when: !agentRules.isEmpty || !modelRules.isEmpty || !branchRules.isEmpty || !blueprintRisks.isEmpty
                ) {
                    VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                        if !agentRules.isEmpty {
                            StageBulletsView(items: agentRules)
                        }
                        if !modelRules.isEmpty {
                            StageBulletsView(items: modelRules)
                        }
                        if !branchRules.isEmpty {
                            StageBulletsView(items: branchRules)
                        }
                        if !blueprintRisks.isEmpty {
                            StageLabeledListView(title: "风险提示", items: blueprintRisks)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }
}
