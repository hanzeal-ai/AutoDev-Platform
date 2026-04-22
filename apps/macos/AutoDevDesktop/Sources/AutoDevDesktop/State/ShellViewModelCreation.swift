import Foundation

extension ShellViewModel {
    func applyCreationMessageResult(
        threadID: UUID,
        assistantMessage _: String?,
        reportDraft: DaemonFeasibilityReport?
    ) {
        guard let index = state.creationThreads.firstIndex(where: { $0.id == threadID }) else {
            return
        }
        if let reportDraft {
            state.creationThreads[index].reportDraft = FeasibilityReportDraft(
                projectName: reportDraft.projectName,
                problemDefinition: reportDraft.problemDefinition,
                targetUsers: reportDraft.targetUsers,
                coreCapabilities: reportDraft.coreCapabilities,
                risksAndConstraints: reportDraft.risksAndConstraints,
                initialDeliveryPlan: reportDraft.initialDeliveryPlan,
                feasibilityConclusion: reportDraft.feasibilityConclusion,
                version: reportDraft.version,
                reportDownloadPath: reportDraft.reportDownloadPath,
                updatedAt: reportDraft.updatedAt
            )
        }
        state.creationThreads[index].lastUpdated = "刚刚"
        state.selectCreationThread(threadID)
    }
}
