import Foundation

extension ShellViewState {
    var selectedExecutionDetailKey: ProjectExecutionDetailKey? {
        guard let project = selectedProject else {
            return nil
        }
        return ProjectExecutionDetailKey(projectID: project.id, stage: activeDetailStage)
    }

    var selectedExecutionDetail: DeliveryExecutionDetail? {
        guard let key = selectedExecutionDetailKey else {
            return nil
        }
        return executionDetails[key]
    }

    var selectedWorkflowSnapshot: DeliveryWorkflowSnapshot? {
        guard let project = selectedProject else {
            return nil
        }
        return workflowSnapshots[project.id]
    }

    var activeDetailStage: DeliveryLifecycleStage {
        selectedDetailStage ?? selectedProject?.lifecycleStage ?? .development
    }

    var selectedStageBlueprint: StageViewBlueprint? {
        stageBlueprints[activeDetailStage]
    }

    var selectedDetailDecisionQuestion: String {
        if !stageAutomation.stageNeedsConfirmation(activeDetailStage) {
            if let detail = selectedExecutionDetail, let aiRun = detail.aiRun, aiRun.isActive {
                return "后台 AI 正在自动处理，完成后将自动推进到下一阶段"
            }
        }
        switch activeDetailStage {
        case .feasibility:
            return "是否确认立项并进入 PRD"
        case .prd:
            return "是否冻结需求边界"
        case .ui:
            return "是否确认方案可进入研发"
        case .development:
            return "继续自动推进还是人工介入"
        case .testing:
            return "是否达到发布门槛"
        case .release:
            return "是否执行发布或回滚"
        case .maintenance:
            return "记录问题继续维护，还是触发新一轮立项"
        }
    }
}
