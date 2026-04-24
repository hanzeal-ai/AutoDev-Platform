import Foundation

struct AIExecutionStateHelper {
    let detail: DeliveryExecutionDetail?
    let stage: DeliveryLifecycleStage
    let downloads: [StageDownloadItem]

    var latestEvents: [DeliveryEventItem] {
        (detail?.events ?? []).filter {
            $0.title.contains("后台 AI") || $0.title.hasPrefix("AI：")
                || $0.title.hasPrefix("系统：") || $0.title.hasPrefix("Agent：")
        }
    }

    var visibleEvents: [DeliveryEventItem] {
        latestEvents.filter { event in
            !event.title.hasPrefix("系统：创建阶段 Agent")
                && !event.title.hasPrefix("系统：发送任务指令")
                && !event.title.contains("正在等待 Agent 回复")
                && !event.title.hasPrefix("Agent：阶段回复")
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

    var executionState: AIExecutionState {
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

    var visibleMessages: [AITranscriptMessage] {
        visibleEvents.compactMap { event in
            if event.title.hasPrefix("Agent："),
               event.detail.count > 200
            {
                return nil
            }
            return AITranscriptMessage(kind: kind(for: event), title: event.title, body: event.detail, footnote: event.time)
        }
    }

    var writingStatusMessage: AITranscriptMessage? {
        let stageName = stage.rawValue
        switch executionState {
        case .waitingFirstDelta:
            return AITranscriptMessage(
                kind: .loading,
                title: "准备写入",
                body: "正在等待 AI 开始生成 \(stageName) 文档…",
                footnote: latestActivity?.time ?? ""
            )
        case .outputting:
            let deltaCount = detail?.aiRun?.deltaCount ?? 0
            return AITranscriptMessage(
                kind: .output,
                title: "正在写入 \(stageName) 文档",
                body: "已接收 \(deltaCount) 个内容片段，写入中…",
                footnote: latestActivity?.time ?? ""
            )
        case .postProcessing:
            return AITranscriptMessage(
                kind: .output,
                title: "正在整理 \(stageName) 文档",
                body: "AI 输出完成，正在写入文件…",
                footnote: latestActivity?.time ?? ""
            )
        case .completed:
            return AITranscriptMessage(
                kind: .file,
                title: "\(stageName) 文档已生成",
                body: artifactItems.isEmpty ? "文档已写入，可在阶段产物中查看。" : "\(artifactItems.count) 个文件已输出。",
                footnote: latestActivity?.time ?? ""
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

    var scrollAnchorID: String {
        let artifactPart = artifactItems.map { "\($0.title):\($0.filePath ?? "")" }.joined(separator: "|")
        return "\(executionState.label)|\(thinkingEvents.count)|\(detail?.aiRun?.deltaCount ?? 0)|\(artifactPart)"
    }

    var statusLine: String {
        switch executionState {
        case .waitingFirstDelta:
            return "请求已发送，等待模型开始返回"
        case .outputting:
            return "后台 Agent 正在流式输出"
        case .postProcessing:
            return "后台正在整理阶段结果"
        case .completed:
            return "后台 AI 已返回阶段结果"
        case .failed:
            return "后台 AI 生成失败，可手动重试"
        case .waiting:
            return "等待后台自动触发"
        }
    }

    func kind(for event: DeliveryEventItem) -> AITranscriptKind {
        if event.title.hasPrefix("Agent：") {
            return .output
        }
        if event.title.contains("已写入阶段结果") {
            return .file
        }
        if event.title.contains("生成失败") {
            return .system
        }
        return .output
    }
}
