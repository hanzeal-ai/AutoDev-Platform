import SwiftUI

enum ProjectWorkflowStatusPresentation {
    static func color(for status: DeliveryWorkflowNodeStatus) -> Color {
        switch status {
        case .completed:
            return .green
        case .running:
            return .accentColor
        case .failed:
            return .red
        case .blocked:
            return .orange
        case .awaitingUserInput:
            return .purple
        case .notStarted, .pending:
            return .secondary
        }
    }

    static func label(for status: DeliveryWorkflowNodeStatus) -> String {
        switch status {
        case .notStarted:
            return "未开始"
        case .pending:
            return "等待"
        case .running:
            return "执行中"
        case .completed:
            return "完成"
        case .failed:
            return "失败"
        case .blocked:
            return "阻塞"
        case .awaitingUserInput:
            return "待补充"
        }
    }

    static func title(for stage: String) -> String {
        switch stage {
        case "chat": return "需求澄清"
        case "report": return "可行性分析"
        case "prd": return "产品需求"
        case "prd_review": return "需求评审"
        case "development": return "研发规划"
        case "coding": return "代码生成"
        case "code_review": return "代码评审"
        case "summary": return "项目总结"
        default: return "Workflow"
        }
    }

    static func overviewTitle(for stage: String) -> String {
        switch stage {
        case "chat": return "需求澄清"
        case "report": return "可行性报告"
        case "prd": return "PRD"
        case "prd_review": return "需求评审"
        case "development": return "研发计划"
        case "coding": return "编码"
        case "code_review": return "代码评审"
        case "summary": return "总结"
        default: return stage
        }
    }
}

enum WorkflowActivityPresentation {
    static func activity(
        snapshot: DeliveryWorkflowSnapshot?,
        detail: DeliveryExecutionDetail?,
        now: Date = Date()
    ) -> DeliveryWorkflowActivityState {
        guard let snapshot else { return .loading }
        switch snapshot.status {
        case .failed:
            return .failed
        case .blocked:
            return .blocked
        case .awaitingUserInput:
            return .awaitingUserInput
        case .completed:
            return .completed
        case .notStarted, .pending:
            return .notStarted
        case .running:
            break
        }

        guard let aiRun = detail?.aiRun, aiRun.isActive else {
            return .running
        }
        if aiRun.status == "waiting_first_delta" || aiRun.firstDeltaAtMs == nil {
            return .waitingFirstToken
        }
        let idleMs = Int64(now.timeIntervalSince1970 * 1000) - aiRun.updatedAtMs
        if idleMs > 90_000 {
            return .idleSuspected
        }
        return .running
    }

    static func color(for activity: DeliveryWorkflowActivityState) -> Color {
        switch activity {
        case .running:
            return .accentColor
        case .waitingFirstToken:
            return .blue
        case .idleSuspected:
            return .orange
        case .awaitingUserInput:
            return .purple
        case .blocked:
            return .orange
        case .failed:
            return .red
        case .completed:
            return .green
        case .loading, .notStarted:
            return .secondary
        }
    }

    static func label(for activity: DeliveryWorkflowActivityState) -> String {
        switch activity {
        case .loading:
            return "读取中"
        case .notStarted:
            return "未开始"
        case .running:
            return "正在工作"
        case .waitingFirstToken:
            return "等待首响应"
        case .idleSuspected:
            return "可能卡住"
        case .awaitingUserInput:
            return "待补充"
        case .blocked:
            return "阻塞"
        case .failed:
            return "失败"
        case .completed:
            return "完成"
        }
    }

    static func detail(
        for activity: DeliveryWorkflowActivityState,
        snapshot: DeliveryWorkflowSnapshot?,
        detail: DeliveryExecutionDetail?,
        now: Date = Date()
    ) -> String {
        guard let snapshot else { return "正在读取 Workflow 状态。" }
        switch activity {
        case .loading:
            return "正在读取 Workflow 状态。"
        case .notStarted:
            return "Workflow 尚未开始执行。"
        case .running:
            return "当前 Agent 正在执行，最近有运行事件更新。"
        case .waitingFirstToken:
            return "请求已发出，正在等待模型返回首个响应。"
        case .idleSuspected:
            if let updatedAtMs = detail?.aiRun?.updatedAtMs {
                return "最近 \(elapsedLabel(since: updatedAtMs, now: now)) 无新事件，建议关注是否卡住。"
            }
            return "执行中但暂无新的过程事件，建议关注是否卡住。"
        case .awaitingUserInput:
            return "当前流程等待用户补充信息或确认。"
        case .blocked:
            return blockedReason(snapshot: snapshot)
        case .failed:
            return snapshot.error?.isEmpty == false ? snapshot.error ?? "执行失败。" : "执行失败。"
        case .completed:
            return "Workflow 已完成。"
        }
    }

    private static func blockedReason(snapshot: DeliveryWorkflowSnapshot) -> String {
        let reason = snapshot.events
            .filter { $0.status == .blocked || $0.status == .failed }
            .sorted { $0.sequence > $1.sequence }
            .first?
            .detail
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return reason?.isEmpty == false ? reason ?? "流程阻塞。" : "流程阻塞，等待人工处理。"
    }

    private static func elapsedLabel(since updatedAtMs: Int64, now: Date) -> String {
        let nowMs = Int64(now.timeIntervalSince1970 * 1000)
        let seconds = max(0, (nowMs - updatedAtMs) / 1000)
        if seconds < 60 {
            return "\(seconds) 秒"
        }
        return "\(seconds / 60) 分钟"
    }
}
