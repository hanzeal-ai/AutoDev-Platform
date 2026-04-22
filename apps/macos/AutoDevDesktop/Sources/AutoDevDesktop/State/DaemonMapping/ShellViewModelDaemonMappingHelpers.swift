import Foundation

extension ShellViewModel {
    static func lifecycleStage(from raw: String) -> DeliveryLifecycleStage {
        switch raw {
        case "feasibility":
            return .feasibility
        case "prd":
            return .prd
        case "ui":
            return .ui
        case "testing":
            return .testing
        case "release":
            return .release
        case "maintenance":
            return .maintenance
        default:
            return .development
        }
    }

    static func stageKey(_ stage: DeliveryLifecycleStage) -> String {
        switch stage {
        case .feasibility:
            return "feasibility"
        case .prd:
            return "prd"
        case .ui:
            return "ui"
        case .development:
            return "development"
        case .testing:
            return "testing"
        case .release:
            return "release"
        case .maintenance:
            return "maintenance"
        }
    }

    static func projectStatus(from raw: String) -> ProjectStatus {
        switch raw {
        case "running":
            return .running
        case "queued":
            return .queued
        case "awaiting_confirmation":
            return .awaitingConfirmation
        case "blocked":
            return .blocked
        case "failed":
            return .failed
        case "completed":
            return .completed
        case "archived":
            return .archived
        default:
            return .running
        }
    }

    static func projectRisk(from raw: String) -> ProjectRisk {
        switch raw {
        case "high":
            return .high
        case "low":
            return .low
        default:
            return .medium
        }
    }

    static func alertLevel(from raw: String) -> AlertLevel {
        switch raw {
        case "critical":
            return .critical
        case "info":
            return .info
        default:
            return .warning
        }
    }

    static func interventionPriority(from raw: String) -> InterventionPriority {
        switch raw {
        case "critical":
            return .critical
        case "low":
            return .low
        default:
            return .normal
        }
    }

    static func materialStatus(from raw: String) -> MaterialAnalysisStatus {
        switch raw {
        case "analyzed":
            return .analyzed
        default:
            return .queued
        }
    }
}
