import Foundation

extension ShellViewState {
    static var runningStatuses: [ProjectStatus] {
        [.running, .queued, .awaitingConfirmation, .blocked, .failed]
    }

    static var closedStatuses: [ProjectStatus] {
        [.archived, .completed]
    }

    static func defaultPrimaryAction(for stage: DeliveryLifecycleStage) -> String {
        switch stage {
        case .feasibility:
            return "确认立项"
        case .prd:
            return "确认 PRD"
        case .ui:
            return "确认 UI 方案"
        case .development:
            return "继续推进"
        case .testing:
            return "确认发布"
        case .release:
            return "确认发布"
        case .maintenance:
            return "记录问题"
        }
    }

    static func defaultSecondaryActions(for stage: DeliveryLifecycleStage) -> [String] {
        switch stage {
        case .feasibility:
            return ["继续讨论", "补充资料"]
        case .prd:
            return ["回退立项", "进入 UI"]
        case .ui:
            return ["回退 PRD", "进入研发"]
        case .development:
            return ["人工介入", "进入测试"]
        case .testing:
            return ["重新测试", "回退研发"]
        case .release:
            return ["暂停发布", "执行回滚"]
        case .maintenance:
            return ["触发新立项", "归档项目"]
        }
    }

    static func defaultRiskItems(for stage: DeliveryLifecycleStage, blockerReason: String?) -> [String] {
        var items: [String]
        switch stage {
        case .feasibility:
            items = ["问题定义不闭合", "关键约束缺失", "资料结论冲突"]
        case .prd:
            items = ["范围膨胀", "需求不完整", "依赖未确认"]
        case .ui:
            items = ["交互冲突", "信息架构不清", "视觉未定稿"]
        case .development:
            items = ["依赖阻塞", "实现风险", "资源不足", "失败重试"]
        case .testing:
            items = ["关键失败项", "阻塞未清", "质量未达标"]
        case .release:
            items = ["发布阻塞", "检查项未通过", "回滚风险"]
        case .maintenance:
            items = ["运行异常", "反馈集中", "质量回落"]
        }
        if let blockerReason = blockerReason, !blockerReason.isEmpty {
            items.insert("阻塞：\(blockerReason)", at: 0)
        }
        return items
    }
}
