import Foundation

enum DevelopmentWorkUnitPresenter {
    static func displayUnits(for detail: DeliveryExecutionDetail?) -> [DeliveryWorkUnitItem] {
        detail?.workUnits ?? []
    }

    static func displayUnits(for detail: DeliveryExecutionDetail) -> [DeliveryWorkUnitItem] {
        detail.workUnits
    }

    static func activeUnit(in units: [DeliveryWorkUnitItem]) -> DeliveryWorkUnitItem? {
        units.first(where: { $0.status == .running })
            ?? units.first(where: { $0.status == .blocked || $0.status == .queued })
            ?? units.first
    }

    static func subTasks(for unit: DeliveryWorkUnitItem) -> [DeliverySubTaskItem] {
        if !unit.subTasks.isEmpty {
            return unit.subTasks
        }

        let titles: [String]
        switch unit.id {
        case "input-consolidation", "requirement-analysis":
            titles = ["收集项目输入", "整理需求边界", "确认验收标准"]
        case "api-contract":
            titles = ["选择后端架构", "定义接口契约", "生成接口文档"]
        case "frontend-backend-task-split":
            titles = ["拆分前端页面与功能", "拆分后端接口与服务", "绑定产物下载入口"]
        case "implementation-review-test":
            titles = ["生成编码队列", "配置 Review 规则", "确认测试入口"]
        default:
            titles = ["准备上下文", "执行当前任务", "产出阶段结果"]
        }

        return titles.enumerated().map { index, title in
            let itemProgress = progressForSubTask(at: index, total: titles.count, unit: unit)
            return DeliverySubTaskItem(
                id: "\(unit.id)-subtask-\(index)",
                title: title,
                status: statusForSubTask(progress: itemProgress, unit: unit),
                progress: itemProgress
            )
        }
    }

    private static func progressForSubTask(at index: Int, total: Int, unit: DeliveryWorkUnitItem) -> Double {
        guard total > 0 else { return 0 }
        let scaled = unit.progress * Double(total)
        return min(max(scaled - Double(index), 0), 1)
    }

    private static func statusForSubTask(progress: Double, unit: DeliveryWorkUnitItem) -> ProjectStatus {
        if progress >= 1 {
            return .completed
        }
        if progress > 0 {
            return unit.status == .blocked ? .blocked : .running
        }
        return unit.status == .blocked ? .blocked : .queued
    }
}
