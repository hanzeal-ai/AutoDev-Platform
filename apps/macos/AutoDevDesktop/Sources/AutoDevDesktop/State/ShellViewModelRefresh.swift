import AppKit
import Foundation

extension ShellViewModel {
    func refreshLiveSnapshot() async throws {
        try await refreshOverviewAndProjects()
        try await refreshCreationThreads()
        await refreshSelectedProjectDetail()
    }

    func refreshOverviewAndProjects() async throws {
        async let overview = daemonClient.getOverview()
        async let projects = daemonClient.listProjects()
        let (resolvedOverview, resolvedProjects) = try await (overview, projects)

        state.opsSnapshot = Self.mapOpsSnapshot(resolvedOverview.opsSnapshot)
        state.managedAlerts = resolvedOverview.managedAlerts.compactMap { Self.mapAlert($0) }
        state.progressNotices = resolvedOverview.progressNotices.compactMap { Self.mapProgressNotice($0) }
        state.interventions = resolvedOverview.interventions.compactMap { Self.mapIntervention($0) }
        state.lifecycleDistribution = resolvedOverview.lifecycleDistribution.map { Self.mapLifecycleStageItem($0) }
        state.projects = resolvedProjects.compactMap { Self.mapProject($0) }
    }

    func refreshCreationThreads() async throws {
        let threads = try await daemonClient.listCreationThreads()
        state.replaceCreationThreads(threads.compactMap { Self.mapCreationThread($0) })
    }

    func scheduleSelectedProjectDetailRefresh() {
        detailRefreshTask?.cancel()
        detailRefreshTask = Task { [weak self] in
            await self?.refreshSelectedProjectDetail()
        }
    }

    func refreshSelectedProjectDetail() async {
        guard dataMode == .liveDaemon else {
            return
        }
        guard let requestKey = state.selectedExecutionDetailKey else {
            return
        }
        do {
            let detail = try await daemonClient.getProjectStageDetail(
                projectID: requestKey.projectID.uuidString,
                stage: Self.stageKey(requestKey.stage)
            )
            guard !Task.isCancelled, state.selectedExecutionDetailKey == requestKey else {
                return
            }
            state.executionDetails[requestKey] = Self.mapStageDetail(detail)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled, state.selectedExecutionDetailKey == requestKey else {
                return
            }
            state.apply(operationError: error, context: "刷新阶段详情")
        }
    }

    func openLocalPath(_ path: String) {
        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.open(url)
        } else {
            state.triggerStageAction("文件不存在：\(url.lastPathComponent)")
        }
    }
}
