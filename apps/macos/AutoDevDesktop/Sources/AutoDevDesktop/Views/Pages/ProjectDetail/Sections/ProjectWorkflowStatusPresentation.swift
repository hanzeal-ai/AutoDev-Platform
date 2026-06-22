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
