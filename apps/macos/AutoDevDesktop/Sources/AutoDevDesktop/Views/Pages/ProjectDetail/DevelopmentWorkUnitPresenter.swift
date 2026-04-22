import Foundation

enum DevelopmentWorkUnitPresenter {
    static func displayUnits(for detail: DeliveryExecutionDetail?) -> [DeliveryWorkUnitItem] {
        guard let detail = detail else {
            return placeholderWorkUnits
        }
        return displayUnits(for: detail)
    }

    static func displayUnits(for detail: DeliveryExecutionDetail) -> [DeliveryWorkUnitItem] {
        detail.workUnits.isEmpty ? placeholderWorkUnits : detail.workUnits
    }

    static func activeUnit(in units: [DeliveryWorkUnitItem]) -> DeliveryWorkUnitItem {
        units.first(where: { $0.status == .running })
            ?? units.first(where: { $0.status == .blocked || $0.status == .queued })
            ?? units.first
            ?? placeholderWorkUnits[0]
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

private extension DevelopmentWorkUnitPresenter {
    static let placeholderWorkUnits: [DeliveryWorkUnitItem] = [
        DeliveryWorkUnitItem(
            id: "requirement-analysis",
            title: "前后端需求分析",
            agentRole: "需求分析 Agent",
            status: .running,
            progress: 0.25,
            dependsOn: [],
            currentOutput: "需求拆分占位",
            nextStep: "冻结需求边界后生成任务拆分",
            downloads: []
        ),
        DeliveryWorkUnitItem(
            id: "api-contract",
            title: "接口契约与架构选择",
            agentRole: "后端规划 Agent",
            status: .blocked,
            progress: 0,
            dependsOn: ["requirement-analysis"],
            currentOutput: nil,
            nextStep: "等待需求分析完成",
            downloads: [
                StageDownloadItem(
                    id: UUID(),
                    title: "接口契约",
                    category: .stageSnapshot,
                    availability: .pending,
                    filePath: nil
                ),
            ]
        ),
        DeliveryWorkUnitItem(
            id: "frontend-backend-task-split",
            title: "前后端任务拆分",
            agentRole: "任务拆分 Agent",
            status: .blocked,
            progress: 0,
            dependsOn: ["requirement-analysis", "api-contract"],
            currentOutput: nil,
            nextStep: "等待接口契约后拆分可执行任务",
            downloads: [
                StageDownloadItem(
                    id: UUID(),
                    title: "前端任务拆分",
                    category: .stageSnapshot,
                    availability: .pending,
                    filePath: nil
                ),
                StageDownloadItem(
                    id: UUID(),
                    title: "后端任务拆分",
                    category: .stageSnapshot,
                    availability: .pending,
                    filePath: nil
                ),
            ]
        ),
        DeliveryWorkUnitItem(
            id: "implementation-review-test",
            title: "编码、审查与测试循环",
            agentRole: "实现与审查 Agent",
            status: .blocked,
            progress: 0,
            dependsOn: ["frontend-backend-task-split"],
            currentOutput: nil,
            nextStep: "等待任务拆分完成后开始编码",
            downloads: []
        ),
    ]
}
