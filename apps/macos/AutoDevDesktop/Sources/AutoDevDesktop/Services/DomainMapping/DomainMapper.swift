import Foundation

/// Pure data mapper — converts Daemon DTOs to domain models.
/// Contains no UI or SwiftUI dependencies, enabling reuse across UI frameworks.
enum DomainMapper {

    // MARK: - Projects

    static func mapProject(_ dto: DaemonProject) -> DeliveryProjectItem? {
        guard let id = UUID(uuidString: dto.id) else {
            StructuredLogWriter.write(component: "autodev-app", level: "WARN", message: "invalid project UUID: \(dto.id)")
            return nil
        }
        return DeliveryProjectItem(
            id: id,
            title: dto.title,
            currentPhase: dto.currentPhase,
            lifecycleStage: lifecycleStage(from: dto.lifecycleStage),
            progress: dto.progress,
            currentGoal: dto.currentGoal,
            nextAction: dto.nextAction,
            risk: projectRisk(from: dto.risk),
            blockReason: dto.blockReason,
            status: projectStatus(from: dto.status),
            owner: dto.owner,
            updateTime: dto.updatedAt
        )
    }

    // MARK: - Overview

    static func mapOpsSnapshot(_ dto: DaemonOpsSnapshot) -> DeliveryOpsSnapshot {
        DeliveryOpsSnapshot(
            hostedSystemCount: dto.hostedSystemCount,
            parallelProjectCount: dto.parallelProjectCount,
            activeAgentCount: dto.activeAgentCount,
            queueDepth: dto.queueDepth,
            runningWorkflowCount: dto.runningWorkflowCount,
            slotUsage: dto.slotUsage,
            averageVelocity: dto.averageVelocity,
            resourcePressure: dto.resourcePressure,
            successRate24h: dto.successRate24H,
            leadTimeMedian: dto.leadTimeMedian,
            blockedProjectCount: dto.blockedProjectCount,
            completedToday: dto.completedToday,
            systemHealth: dto.systemHealth
        )
    }

    static func mapAlert(_ dto: DaemonAlert) -> ManagedAlertItem? {
        guard let id = UUID(uuidString: dto.id) else {
            StructuredLogWriter.write(component: "autodev-app", level: "WARN", message: "invalid alert UUID: \(dto.id)")
            return nil
        }
        return ManagedAlertItem(
            id: id,
            title: dto.title,
            projectName: dto.projectName,
            reason: dto.reason,
            nextAction: dto.nextAction,
            level: alertLevel(from: dto.level)
        )
    }

    static func mapProgressNotice(_ dto: DaemonProgressNotice) -> ProgressNoticeItem? {
        guard let id = UUID(uuidString: dto.id) else {
            StructuredLogWriter.write(component: "autodev-app", level: "WARN", message: "invalid notice UUID: \(dto.id)")
            return nil
        }
        return ProgressNoticeItem(
            id: id,
            title: dto.title,
            detail: dto.detail,
            time: dto.time
        )
    }

    static func mapIntervention(_ dto: DaemonIntervention) -> InterventionItem? {
        guard let id = UUID(uuidString: dto.id) else {
            StructuredLogWriter.write(component: "autodev-app", level: "WARN", message: "invalid intervention UUID: \(dto.id)")
            return nil
        }
        return InterventionItem(
            id: id,
            title: dto.title,
            projectName: dto.projectName,
            reason: dto.reason,
            nextAction: dto.nextAction,
            priority: interventionPriority(from: dto.priority)
        )
    }

    static func mapLifecycleStageItem(_ dto: DaemonLifecycleStageItem) -> LifecycleStageItem {
        LifecycleStageItem(stage: lifecycleStage(from: dto.stage), count: dto.count)
    }

    // MARK: - Creation

    static func mapCreationThread(_ dto: DaemonCreationThread) -> CreationThreadSession? {
        guard let id = UUID(uuidString: dto.id) else {
            StructuredLogWriter.write(component: "autodev-app", level: "WARN", message: "invalid thread UUID: \(dto.id)")
            return nil
        }
        let linkedProjectID = dto.linkedProjectId.flatMap(UUID.init(uuidString:))
        let materials = dto.materials.compactMap { mapCreationMaterial($0) }
        let messages = dto.messages.compactMap { mapCreationMessage($0) }
        return CreationThreadSession(
            id: id,
            title: dto.title,
            lastUpdated: dto.lastUpdated,
            isArchived: dto.isArchived,
            linkedProjectID: linkedProjectID,
            lifecycleStage: lifecycleStage(from: dto.lifecycleStage),
            materials: materials,
            messages: messages,
            reportDraft: FeasibilityReportDraft(
                projectName: dto.reportDraft.projectName,
                problemDefinition: dto.reportDraft.problemDefinition,
                targetUsers: dto.reportDraft.targetUsers,
                coreCapabilities: dto.reportDraft.coreCapabilities,
                risksAndConstraints: dto.reportDraft.risksAndConstraints,
                initialDeliveryPlan: dto.reportDraft.initialDeliveryPlan,
                feasibilityConclusion: dto.reportDraft.feasibilityConclusion,
                version: dto.reportDraft.version,
                reportDownloadPath: dto.reportDraft.reportDownloadPath,
                updatedAt: dto.reportDraft.updatedAt
            )
        )
    }

    static func mapCreationMaterial(_ dto: DaemonMaterial) -> CreationMaterialItem? {
        guard let materialID = UUID(uuidString: dto.id) else {
            StructuredLogWriter.write(component: "autodev-app", level: "WARN", message: "invalid material UUID: \(dto.id)")
            return nil
        }
        return CreationMaterialItem(
            id: materialID,
            name: dto.name,
            typeHint: dto.typeHint,
            sizeHint: dto.sizeHint,
            addedAt: dto.addedAt,
            status: materialStatus(from: dto.status),
            downloadPath: dto.downloadPath
        )
    }

    static func mapCreationMessage(_ dto: DaemonCreationMessage) -> CreationConversationMessage? {
        guard let messageID = UUID(uuidString: dto.id) else {
            StructuredLogWriter.write(component: "autodev-app", level: "WARN", message: "invalid message UUID: \(dto.id)")
            return nil
        }
        return CreationConversationMessage(
            id: messageID,
            role: dto.role == "user" ? .user : .ai,
            content: dto.content,
            timestamp: dto.timestamp,
            isLoading: false
        )
    }

    // MARK: - Helpers

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

    static func downloadCategory(from raw: String) -> StageDownloadCategory {
        switch raw {
        case "raw_input":
            return .rawInput
        case "audit_archive":
            return .auditArchive
        default:
            return .stageSnapshot
        }
    }

    static func downloadAvailability(from raw: String) -> StageDownloadAvailability {
        switch raw {
        case "ready":
            return .ready
        case "view_only":
            return .viewOnly
        default:
            return .pending
        }
    }
}
