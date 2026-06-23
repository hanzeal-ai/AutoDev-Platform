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
            async let detailRequest = daemonClient.getProjectStageDetail(
                projectID: requestKey.projectID.uuidString,
                stage: DomainMapper.stageKey(requestKey.stage),
                subStep: state.selectedSubStep
            )
            async let workflowStatusRequest = daemonClient.getProjectWorkflowStatus(
                projectID: requestKey.projectID.uuidString
            )
            async let workflowEventsRequest = daemonClient.listProjectWorkflowEvents(
                projectID: requestKey.projectID.uuidString
            )
            let (detail, workflowStatus, workflowEvents) = try await (
                detailRequest,
                workflowStatusRequest,
                workflowEventsRequest
            )
            guard !Task.isCancelled, state.selectedExecutionDetailKey == requestKey else {
                return
            }
            let mappedDetail = DomainMapper.mapStageDetail(detail)
            state.executionDetails[requestKey] = mappedDetail
            state.workflowSnapshots[requestKey.projectID] = DomainMapper.mapWorkflowSnapshot(
                status: workflowStatus,
                events: workflowEvents
            )
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

    /// Clears the cached stage detail so the UI resets before regeneration.
    func clearSelectedStageUI() {
        guard let key = state.selectedExecutionDetailKey else { return }
        state.executionDetails[key] = nil
    }

    func generateAIForSelectedStage(feedback: String? = nil, action: String = "continue") {
        guard dataMode == .liveDaemon else {
            state.statusMessage = "预览模式不能触发后台 AI"
            return
        }
        guard let requestKey = state.selectedExecutionDetailKey else {
            state.statusMessage = "未选择阶段"
            return
        }
        guard !isGeneratingStageAI || action != "continue" else { return }

        isGeneratingStageAI = true
        state.statusMessage = workflowActionStatusMessage(action: action, hasFeedback: feedback != nil)
        Task { [weak self] in
            guard let self else { return }
            defer { isGeneratingStageAI = false }
            do {
                let shouldStart = state.workflowSnapshots[requestKey.projectID]?.status == .notStarted
                    || state.workflowSnapshots[requestKey.projectID] == nil
                let stream = daemonClient.runProjectWorkflowStreaming(
                    projectID: requestKey.projectID.uuidString,
                    feedback: feedback,
                    action: action,
                    mode: shouldStart ? "start" : "resume"
                )
                state.workflowRawStreamLines[requestKey.projectID] = []
                state.statusMessage = "后台 AI 流式生成中..."
                for await event in stream.stream {
                    guard state.selectedExecutionDetailKey == requestKey else {
                        stream.cancel()
                        return
                    }
                    switch event {
                    case let .raw(rawLine):
                        appendWorkflowRawStreamLine(projectID: requestKey.projectID, line: rawLine)
                    case let .update(status, event):
                        applyWorkflowStreamSnapshot(
                            projectID: requestKey.projectID,
                            status: status,
                            event: event
                        )
                    case let .done(status, event):
                        if let status {
                            applyWorkflowStreamSnapshot(
                                projectID: requestKey.projectID,
                                status: status,
                                event: event
                            )
                        }
                        await refreshSelectedProjectDetail()
                        state.statusMessage = "后台 AI 已返回阶段数据"
                        return
                    case let .error(message):
                        throw DaemonClientError.daemonError(code: "workflow_stream_error", detail: message)
                    }
                }
                await refreshSelectedProjectDetail()
            } catch {
                guard state.selectedExecutionDetailKey == requestKey else { return }
                state.apply(operationError: error, context: "触发后台 AI")
            }
        }
    }

    private func appendWorkflowRawStreamLine(projectID: UUID, line: String) {
        var lines = state.workflowRawStreamLines[projectID] ?? []
        lines.append(line)
        state.workflowRawStreamLines[projectID] = Array(lines.suffix(80))
    }

    private func applyWorkflowStreamSnapshot(
        projectID: UUID,
        status: DaemonProjectWorkflowStatus,
        event: DaemonWorkflowEvent?
    ) {
        let eventPayload = event.map {
            DaemonProjectWorkflowEvents(
                workflowId: status.workflowId,
                threadId: status.threadId,
                projectId: status.projectId,
                projectName: status.projectName,
                currentPhase: status.currentPhase,
                currentStep: status.currentStep,
                status: status.status,
                awaitingUserInput: status.awaitingUserInput,
                error: status.error,
                events: [$0]
            )
        }
        var nextSnapshot = DomainMapper.mapWorkflowSnapshot(status: status, events: eventPayload)
        var previousEvents = state.workflowSnapshots[projectID]?.events ?? []
        if let event, event.detail.contains("重新执行") {
            previousEvents.removeAll { $0.stage == event.stage }
        }
        nextSnapshot.events = mergeWorkflowEvents(previousEvents + nextSnapshot.events)
        state.workflowSnapshots[projectID] = nextSnapshot
    }

    private func mergeWorkflowEvents(_ events: [DeliveryWorkflowEventItem]) -> [DeliveryWorkflowEventItem] {
        var seen = Set<String>()
        let merged = events
            .sorted { $0.sequence < $1.sequence }
            .filter { event in
                let key = event.id.isEmpty
                    ? "\(event.sequence)|\(event.stage)|\(event.detail)"
                    : event.id
                return seen.insert(key).inserted
            }
        return Array(merged.suffix(80))
    }

    func runSelectedWorkflowStep() {
        let status = state.selectedWorkflowSnapshot?.status ?? .notStarted
        generateAIForSelectedStage(action: workflowRunAction(for: status))
    }

    func skipSelectedWorkflowStep() {
        generateAIForSelectedStage(action: "skip")
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

    private func workflowRunAction(for status: DeliveryWorkflowNodeStatus) -> String {
        switch status {
        case .failed, .blocked, .awaitingUserInput:
            return "retry"
        case .running, .completed:
            return "rerun"
        case .notStarted, .pending:
            return "continue"
        }
    }

    private func workflowActionStatusMessage(action: String, hasFeedback: Bool) -> String {
        if hasFeedback {
            return "根据反馈重新生成中..."
        }
        switch action {
        case "skip":
            return "正在跳过当前 Workflow 节点..."
        case "retry":
            return "正在重试当前 Workflow 节点..."
        case "rerun":
            return "正在重新执行当前 Workflow 节点..."
        default:
            return "后台 AI 已启动..."
        }
    }
}
