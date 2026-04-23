import Foundation

extension ShellViewModel {
    func confirmFeasibilityAndEnterPRD() {
        switch dataMode {
        case .sampleOnly:
            state.triggerStageAction("预览模式不支持确认立项")
        case .liveDaemon:
            guard !isConfirmingFeasibility else { return }
            isConfirmingFeasibility = true
            Task { @MainActor in
                do {
                    let threadID = try await resolveActiveCreationThreadIDAfterRefresh()
                    let result = try await daemonClient.confirmFeasibility(threadID: threadID.uuidString)
                    try await refreshLiveSnapshot()
                    if
                        let projectIDRaw = result.projectId,
                        let projectID = UUID(uuidString: projectIDRaw)
                    {
                        state.openProjectDetail(projectID: projectID, from: .projectLibrary)
                        state.selectDetailStage(.prd)
                        await refreshSelectedProjectDetail()
                    }
                } catch {
                    state.apply(operationError: error, context: "确认可行性")
                }
                isConfirmingFeasibility = false
            }
        }
    }

    func confirmFeasibilityAndEnterPRD(threadID: UUID) {
        switch dataMode {
        case .sampleOnly:
            state.triggerStageAction("预览模式不支持确认立项")
        case .liveDaemon:
            guard !isConfirmingFeasibility else { return }
            isConfirmingFeasibility = true
            Task { @MainActor in
                do {
                    let resolvedThreadID = try await resolveActiveCreationThreadIDAfterRefresh(expectedThreadID: threadID)
                    let result = try await daemonClient.confirmFeasibility(threadID: resolvedThreadID.uuidString)
                    try await refreshLiveSnapshot()
                    if
                        let projectIDRaw = result.projectId,
                        let projectID = UUID(uuidString: projectIDRaw)
                    {
                        state.openProjectDetail(projectID: projectID, from: .projectLibrary)
                        state.selectDetailStage(.prd)
                        await refreshSelectedProjectDetail()
                    }
                } catch {
                    state.apply(operationError: error, context: "确认可行性")
                }
                isConfirmingFeasibility = false
            }
        }
    }
}
