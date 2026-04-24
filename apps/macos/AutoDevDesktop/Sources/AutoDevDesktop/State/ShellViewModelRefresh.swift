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

        state.opsSnapshot = DomainMapper.mapOpsSnapshot(resolvedOverview.opsSnapshot)
        state.managedAlerts = resolvedOverview.managedAlerts.compactMap { DomainMapper.mapAlert($0) }
        state.progressNotices = resolvedOverview.progressNotices.compactMap { DomainMapper.mapProgressNotice($0) }
        state.interventions = resolvedOverview.interventions.compactMap { DomainMapper.mapIntervention($0) }
        state.lifecycleDistribution = resolvedOverview.lifecycleDistribution.map { DomainMapper.mapLifecycleStageItem($0) }
        state.projects = resolvedProjects.compactMap { DomainMapper.mapProject($0) }
    }

    func refreshCreationThreads() async throws {
        let threads = try await daemonClient.listCreationThreads()
        state.replaceCreationThreads(threads.compactMap { DomainMapper.mapCreationThread($0) })
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
                stage: DomainMapper.stageKey(requestKey.stage),
                subStep: state.selectedSubStep
            )
            guard !Task.isCancelled, state.selectedExecutionDetailKey == requestKey else {
                return
            }
            let mappedDetail = DomainMapper.mapStageDetail(detail)
            state.executionDetails[requestKey] = mappedDetail
            scheduleStageAIDetailPollingIfNeeded(detail: mappedDetail, requestKey: requestKey)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled, state.selectedExecutionDetailKey == requestKey else {
                return
            }
            state.apply(operationError: error, context: "刷新阶段详情")
        }
    }

    func generateAIForSelectedStage(feedback: String? = nil) {
        guard dataMode == .liveDaemon else {
            state.statusMessage = "预览模式不能触发后台 AI"
            return
        }
        guard let requestKey = state.selectedExecutionDetailKey else {
            state.statusMessage = "未选择阶段"
            return
        }
        guard !isGeneratingStageAI else { return }

        isGeneratingStageAI = true
        state.statusMessage = feedback != nil ? "根据反馈重新生成中..." : "后台 AI 已启动..."
        Task { [weak self] in
            guard let self else { return }
            defer { isGeneratingStageAI = false }
            do {
                _ = try await daemonClient.generateProjectStageAI(
                    projectID: requestKey.projectID.uuidString,
                    stage: DomainMapper.stageKey(requestKey.stage),
                    feedback: feedback
                )
                guard state.selectedExecutionDetailKey == requestKey else { return }
                state.statusMessage = "后台 AI 流式生成中..."
                var pollDelay: UInt64 = 1_000_000_000  // Start at 1 second
                let maxDelay: UInt64 = 5_000_000_000   // Cap at 5 seconds
                let maxPolls = 60
                for _ in 0..<maxPolls {
                    guard !Task.isCancelled else { return }
                    await refreshSelectedProjectDetail()
                    guard state.selectedExecutionDetailKey == requestKey else { return }
                    if let detail = state.executionDetails[requestKey],
                       !Self.stageAIGenerationActive(detail)
                    {
                        state.statusMessage = "后台 AI 已返回阶段数据"
                        return
                    }
                    try await Task.sleep(nanoseconds: pollDelay)
                    pollDelay = min(pollDelay + 500_000_000, maxDelay)
                }
                state.statusMessage = "后台 AI 仍在运行，可稍后刷新查看"
            } catch {
                guard state.selectedExecutionDetailKey == requestKey else { return }
                state.apply(operationError: error, context: "触发后台 AI")
            }
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

    private func scheduleStageAIDetailPollingIfNeeded(
        detail: DeliveryExecutionDetail,
        requestKey: ProjectExecutionDetailKey
    ) {
        stageAIRefreshTask?.cancel()
        guard Self.stageAIGenerationActive(detail) else { return }
        stageAIRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            guard self?.state.selectedExecutionDetailKey == requestKey else { return }
            await self?.refreshSelectedProjectDetail()
        }
    }

    private static func stageAIGenerationActive(_ detail: DeliveryExecutionDetail) -> Bool {
        if let aiRun = detail.aiRun {
            return aiRun.isActive
        }
        return false
    }
}
