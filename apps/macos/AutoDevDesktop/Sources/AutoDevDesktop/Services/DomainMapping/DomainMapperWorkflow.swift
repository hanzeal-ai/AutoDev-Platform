import Foundation

extension DomainMapper {
    static let workflowStageOrder = [
        "prd",
        "prd_review",
        "development",
        "coding",
        "code_review",
        "summary",
    ]

    static func mapWorkflowSnapshot(
        status: DaemonProjectWorkflowStatus,
        events: DaemonProjectWorkflowEvents?
    ) -> DeliveryWorkflowSnapshot {
        let phases = workflowStageOrder.compactMap { stage -> DeliveryWorkflowPhase? in
            guard let phase = status.phases[stage] else { return nil }
            return mapWorkflowPhase(stage: stage, phase: phase)
        }
        let artifactPhases = status.artifacts.map { artifact in
            DeliveryWorkflowPhase(
                id: artifact.artifactId,
                stage: artifact.stage,
                title: artifact.name,
                kind: artifact.kind,
                status: workflowNodeStatus(from: artifact.status),
                artifactID: artifact.artifactId,
                fileName: artifact.fileName,
                filePath: artifact.filePath
            )
        }
        return DeliveryWorkflowSnapshot(
            workflowID: status.workflowId,
            threadID: status.threadId,
            projectID: status.projectId,
            projectName: status.projectName,
            currentPhase: status.currentPhase,
            currentStep: status.currentStep,
            status: workflowNodeStatus(from: status.status),
            awaitingUserInput: status.awaitingUserInput,
            error: status.error,
            phases: phases,
            artifacts: artifactPhases,
            events: (events?.events ?? []).map(mapWorkflowEvent(_:))
        )
    }

    static func workflowNodeStatus(from raw: String) -> DeliveryWorkflowNodeStatus {
        DeliveryWorkflowNodeStatus(rawValue: raw) ?? .pending
    }

    private static func mapWorkflowPhase(
        stage: String,
        phase: DaemonWorkflowPhase
    ) -> DeliveryWorkflowPhase {
        DeliveryWorkflowPhase(
            id: stage,
            stage: stage,
            title: phase.name,
            kind: phase.kind,
            status: workflowNodeStatus(from: phase.status),
            artifactID: phase.artifactId,
            fileName: phase.fileName,
            filePath: phase.filePath
        )
    }

    private static func mapWorkflowEvent(_ event: DaemonWorkflowEvent) -> DeliveryWorkflowEventItem {
        DeliveryWorkflowEventItem(
            id: event.id,
            sequence: event.sequence,
            type: event.type,
            stage: event.stage,
            title: event.title,
            detail: event.detail,
            status: workflowNodeStatus(from: event.status),
            artifactID: event.artifactId,
            createdAtMS: event.createdAtMs
        )
    }
}
