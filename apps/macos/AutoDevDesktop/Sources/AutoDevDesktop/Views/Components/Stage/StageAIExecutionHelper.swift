import Foundation

struct AIExecutionStateHelper {
    let detail: DeliveryExecutionDetail?
    let stage: DeliveryLifecycleStage
    let downloads: [StageDownloadItem]

    // MARK: - Event Filtering

    var latestEvents: [DeliveryEventItem] {
        (detail?.events ?? []).filter {
            $0.title.contains("后台 AI") || $0.title.hasPrefix("AI：")
                || $0.title.hasPrefix("系统：") || $0.title.hasPrefix("Agent：")
        }
    }

    var thinkingEvents: [DeliveryEventItem] {
        latestEvents.filter { event in
            event.title.hasPrefix("系统：创建阶段 Agent")
                || event.title.hasPrefix("系统：发送任务指令")
                || event.title.contains("正在等待 Agent 回复")
                || event.title.hasPrefix("Agent：阶段回复")
        }
    }

    private var visibleEvents: [DeliveryEventItem] {
        latestEvents.filter { event in
            !event.title.hasPrefix("系统：创建阶段 Agent")
                && !event.title.hasPrefix("系统：发送任务指令")
                && !event.title.contains("正在等待 Agent 回复")
                && !event.title.hasPrefix("Agent：阶段回复")
        }
    }

    // MARK: - Execution State

    var executionState: AIExecutionState {
        if shouldWaitForUIInteractionCompletion {
            return .postProcessing
        }
        if let status = detail?.aiRun?.status {
            switch status {
            case "dispatched", "waiting_first_delta":
                return .waitingFirstDelta
            case "streaming":
                return .outputting
            case "post_processing":
                return .postProcessing
            case "completed":
                return .completed
            case "failed", "timed_out":
                return .failed
            default:
                break
            }
        }
        if latestEvents.contains(where: { $0.title.contains("生成失败") }) {
            return .failed
        }
        if detail?.inputContexts.contains(where: { $0.contains("真实 AI：") }) == true
            || latestEvents.contains(where: { $0.title.contains("已写入阶段结果") })
        {
            return .completed
        }
        if latestEvents.contains(where: {
            $0.title.hasPrefix("Agent：")
                && !$0.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) {
            return .outputting
        }
        return .waiting
    }

    var latestActivity: DeliveryEventItem? {
        latestEvents.last
    }

    // MARK: - Thinking Duration

    /// Elapsed seconds for the thinking phase (start → first delta or now).
    var thinkingDurationSeconds: Int? {
        guard let aiRun = detail?.aiRun else { return nil }
        let startMs = aiRun.startedAtMs
        guard startMs > 0 else { return nil }
        let endMs: Int64
        if let firstDelta = aiRun.firstDeltaAtMs, firstDelta > 0 {
            endMs = firstDelta
        } else if executionState.showsSpinner {
            endMs = Int64(Date().timeIntervalSince1970 * 1000)
        } else {
            endMs = aiRun.updatedAtMs > 0 ? aiRun.updatedAtMs : startMs
        }
        return max(0, Int((endMs - startMs) / 1000))
    }

    // MARK: - Conversation Messages

    /// Full conversation flow for the transcript view.
    var conversationMessages: [AITranscriptMessage] {
        var messages: [AITranscriptMessage] = []

        // Visible event-based messages
        for event in visibleEvents {
            if event.title.hasPrefix("Agent："), event.detail.count > 200 {
                continue
            }
            messages.append(AITranscriptMessage(
                kind: messageKind(for: event),
                title: event.title,
                body: event.detail,
                footnote: event.time
            ))
        }

        // Status-driven message (streaming progress / completion / failure)
        if let statusMsg = statusMessage {
            messages.append(statusMsg)
        }

        return messages
    }

    private var statusMessage: AITranscriptMessage? {
        let stageName = executionDisplayName
        switch executionState {
        case .waitingFirstDelta:
            return AITranscriptMessage(
                kind: .agent,
                title: "AutoDev",
                body: "正在准备生成 **\(stageName)** 文档…",
                footnote: latestActivity?.time ?? ""
            )
        case .outputting:
            let deltaCount = detail?.aiRun?.deltaCount ?? 0
            return AITranscriptMessage(
                kind: .agent,
                title: "AutoDev",
                body: "正在生成 **\(stageName)** 文档…",
                footnote: latestActivity?.time ?? "",
                isStreaming: true,
                deltaCount: deltaCount
            )
        case .postProcessing:
            if shouldWaitForUIInteractionCompletion {
                return AITranscriptMessage(
                    kind: .agent,
                    title: "AutoDev",
                    body: "**交互稿** 内容已返回，正在等待原型文件写入完成…",
                    footnote: latestActivity?.time ?? ""
                )
            }
            return AITranscriptMessage(
                kind: .agent,
                title: "AutoDev",
                body: "**\(stageName)** 文档输出完成，正在写入文件…",
                footnote: latestActivity?.time ?? ""
            )
        case .completed:
            let body: String
            if artifactItems.isEmpty {
                body = "**\(stageName)** 文档已生成完成，可在阶段产物中查看。"
            } else {
                body = "**\(stageName)** 文档已生成完成。"
            }
            return AITranscriptMessage(
                kind: .agent,
                title: "AutoDev",
                body: body,
                footnote: latestActivity?.time ?? "",
                artifacts: artifactItems
            )
        case .failed:
            let errorMsg = detail?.aiRun?.errorMessage ?? "未知原因"
            return AITranscriptMessage(
                kind: .system,
                title: "生成失败",
                body: errorMsg,
                footnote: latestActivity?.time ?? ""
            )
        case .waiting:
            return nil
        }
    }

    private var executionDisplayName: String {
        guard stage == .ui else { return stage.rawValue }
        switch detail?.activeSubStep {
        case "page_map":
            return "页面地图"
        case "interaction":
            return "交互稿"
        default:
            return stage.rawValue
        }
    }

    // MARK: - Artifacts

    var artifactItems: [StageDownloadItem] {
        var items = downloads.filter { item in
            item.filePath?.isEmpty == false && item.availability != .pending
        }
        let outputFiles = (detail?.outputArtifacts ?? []).compactMap { artifact -> StageDownloadItem? in
            guard let path = artifact.filePath, !path.isEmpty else { return nil }
            guard !items.contains(where: { $0.filePath == path }) else { return nil }
            return StageDownloadItem(
                id: artifact.id,
                title: artifact.name,
                category: .stageSnapshot,
                availability: .ready,
                filePath: path
            )
        }
        items.append(contentsOf: outputFiles)
        return items
    }

    private var shouldWaitForUIInteractionCompletion: Bool {
        guard stage == .ui else { return false }
        guard (detail?.activeSubStep == "interaction")
            || (detail?.subSteps.first(where: { $0.key == "interaction" }) != nil) else {
            return false
        }
        guard detail?.aiRun?.status == "completed" else { return false }
        return detail?.subSteps.first(where: { $0.key == "interaction" })?.hasContent != true
    }

    // MARK: - Task Checklist

    var taskItems: [DeliveryStepProgressItem] {
        let raw = detail?.stepProgress ?? []
        guard !raw.isEmpty else { return raw }

        switch executionState {
        case .completed:
            // All tasks done when AI is completed
            return raw.map { item in
                var copy = item
                copy.status = .completed
                return copy
            }
        case .failed:
            // Mark running tasks as failed, keep others
            return raw.map { item in
                var copy = item
                if copy.status == .running {
                    copy.status = .failed
                }
                return copy
            }
        default:
            return raw
        }
    }

    var taskSectionTitle: String {
        guard stage == .ui else { return "任务" }
        switch detail?.activeSubStep {
        case "page_map":
            return "页面地图任务"
        case "interaction":
            return "交互稿任务"
        default:
            return "UI 任务"
        }
    }

    var thinkingSectionTitle: String {
        guard stage == .ui else { return "" }
        switch detail?.activeSubStep {
        case "page_map":
            return "页面地图"
        case "interaction":
            return "交互稿"
        default:
            return "UI"
        }
    }

    // MARK: - Scroll Anchor

    var scrollAnchorID: String {
        let artifactPart = artifactItems.map { "\($0.title):\($0.filePath ?? "")" }.joined(separator: "|")
        return "\(executionState.label)|\(thinkingEvents.count)|\(detail?.aiRun?.deltaCount ?? 0)|\(artifactPart)"
    }

    // MARK: - Helpers

    private func messageKind(for event: DeliveryEventItem) -> AITranscriptKind {
        if event.title.hasPrefix("Agent：") {
            return .agent
        }
        if event.title.contains("已写入阶段结果") {
            return .agent
        }
        if event.title.contains("生成失败") {
            return .system
        }
        return .agent
    }
}
