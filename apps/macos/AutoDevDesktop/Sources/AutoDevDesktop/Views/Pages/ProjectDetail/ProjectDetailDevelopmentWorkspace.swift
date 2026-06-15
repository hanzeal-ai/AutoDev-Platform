import SwiftUI

extension ProjectDetailPage {
    func developmentWorkspace(detail: DeliveryExecutionDetail?) -> some View {
        let activeSubStep = detail?.activeSubStep ?? viewModel.state.selectedSubStep ?? "task_breakdown"

        return VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
            if activeSubStep == "coding" {
                developmentCodingContent(detail: detail)
            } else if activeSubStep == "code_review" {
                developmentCodeReviewContent(detail: detail)
            } else if activeSubStep == "summary" {
                developmentSummaryContent(detail: detail)
            } else {
                developmentTaskBreakdownContent(detail: detail)
            }
        }
    }

    @ViewBuilder
    private func developmentTaskBreakdownContent(detail: DeliveryExecutionDetail?) -> some View {
        let techStack = detail?.inputContexts ?? []
        let apiContracts = detail?.riskItems ?? []
        let blueprint = viewModel.state.selectedStageBlueprint
        let outputs = detail?.outputArtifacts ?? []
        let workUnits = DevelopmentWorkUnitPresenter.displayUnits(for: detail)
        let activeUnit = DevelopmentWorkUnitPresenter.activeUnit(in: workUnits)
        let blueprintOutputs = blueprint?.outputArtifacts ?? []
        let blueprintRisks = blueprint?.riskItems ?? []

        stageModule("技术栈", when: !techStack.isEmpty) {
            StageBulletsView(items: techStack)
        }

        stageModule("模块设计", when: !(detail?.stepProgress.isEmpty ?? true)) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(detail?.stepProgress ?? []) { step in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(devStepColor(step.status))
                            .frame(width: 8, height: 8)
                        Text(step.title)
                            .font(.subheadline)
                            .lineLimit(2)
                            .foregroundColor(.primary)
                    }
                }
            }
        }

        stageModule("接口契约", when: !apiContracts.isEmpty) {
            StageBulletsView(items: apiContracts)
        }

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

            stageModule("脚手架文件", when: !workUnits.isEmpty) {
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
                        StageArtifactListView(viewModel: viewModel, items: outputs)
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

            stageModule("风险提示", when: !blueprintRisks.isEmpty) {
                StageLabeledListView(title: "风险提示", items: blueprintRisks)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private func developmentCodingContent(detail: DeliveryExecutionDetail?) -> some View {
        let outputs = detail?.outputArtifacts ?? []
        let workUnits = DevelopmentWorkUnitPresenter.displayUnits(for: detail)

        stageModule("生成概述", when: !(detail?.objective.isEmpty ?? true)) {
            Text(detail?.objective ?? "")
                .font(.subheadline)
                .foregroundColor(.primary)
        }

        stageModule("生成的代码文件", when: !(detail?.stepProgress.isEmpty ?? true)) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(detail?.stepProgress ?? []) { step in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(devStepColor(step.status))
                            .frame(width: 8, height: 8)
                        Text(step.title)
                            .font(.system(.subheadline, design: .monospaced))
                            .lineLimit(2)
                            .foregroundColor(.primary)
                    }
                }
            }
        }

        stageModule("代码执行单元", when: !workUnits.isEmpty) {
            DevelopmentWorkUnitBoard(viewModel: viewModel, units: workUnits)
        }

        stageModule("阶段产物", when: !outputs.isEmpty) {
            StageArtifactListView(viewModel: viewModel, items: outputs)
        }
    }

    @ViewBuilder
    private func developmentCodeReviewContent(detail: DeliveryExecutionDetail?) -> some View {
        let issues = detail?.stepProgress ?? []
        let changes = detail?.eventFlow ?? []
        let risks = detail?.riskItems ?? []
        let outputs = detail?.outputArtifacts ?? []
        let workUnits = DevelopmentWorkUnitPresenter.displayUnits(for: detail)

        stageModule("评审结论", when: !(detail?.objective.isEmpty ?? true)) {
            Text(detail?.objective ?? "")
                .font(.subheadline)
                .foregroundColor(.primary)
        }

        stageModule("评审状态", when: !(detail?.inputContexts.isEmpty ?? true)) {
            StageBulletsView(items: detail?.inputContexts ?? [])
        }

        stageModule("评审问题", when: !issues.isEmpty) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(issues) { step in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(devStepColor(step.status))
                            .frame(width: 8, height: 8)
                        Text(step.title)
                            .font(.subheadline)
                            .lineLimit(2)
                    }
                }
            }
        }

        stageModule("必要修改", when: !changes.isEmpty || !risks.isEmpty) {
            StageBulletsView(items: changes.isEmpty ? risks : changes)
        }

        stageModule("评审执行单元", when: !workUnits.isEmpty) {
            DevelopmentWorkUnitBoard(viewModel: viewModel, units: workUnits)
        }

        stageModule("阶段产物", when: !outputs.isEmpty) {
            StageArtifactListView(viewModel: viewModel, items: outputs)
        }
    }

    @ViewBuilder
    private func developmentSummaryContent(detail: DeliveryExecutionDetail?) -> some View {
        let steps = detail?.stepProgress ?? []
        let outputs = detail?.outputArtifacts ?? []

        stageModule("流程总结", when: !(detail?.objective.isEmpty ?? true)) {
            Text(detail?.objective ?? "")
                .font(.subheadline)
                .foregroundColor(.primary)
        }

        stageModule("评审轮次", when: !(detail?.inputContexts.isEmpty ?? true)) {
            StageBulletsView(items: detail?.inputContexts ?? [])
        }

        stageModule("完成项", when: !steps.isEmpty) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(steps) { step in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(devStepColor(step.status))
                            .frame(width: 8, height: 8)
                        Text(step.title)
                            .font(.subheadline)
                            .lineLimit(2)
                    }
                }
            }
        }

        stageModule("阶段产物", when: !outputs.isEmpty) {
            StageArtifactListView(viewModel: viewModel, items: outputs)
        }
    }

    private func devStepColor(_ status: ProjectStatus) -> Color {
        switch status {
        case .completed: return .green
        case .running: return .accentColor
        case .blocked, .failed: return .red
        default: return .secondary
        }
    }
}
