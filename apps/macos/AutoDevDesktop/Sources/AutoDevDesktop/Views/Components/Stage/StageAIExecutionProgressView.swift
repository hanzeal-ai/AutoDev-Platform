import SwiftUI

struct StageAIExecutionProgressView: View {
    @ObservedObject var viewModel: ShellViewModel
    let stage: DeliveryLifecycleStage
    let detail: DeliveryExecutionDetail?
    let downloads: [StageDownloadItem]
    @State private var thinkingExpanded = false

    private var latestEvents: [DeliveryEventItem] {
        (detail?.events ?? []).filter {
            $0.title.contains("后台 AI") || $0.title.hasPrefix("AI：")
                || $0.title.hasPrefix("系统：") || $0.title.hasPrefix("Agent：")
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

    private var thinkingEvents: [DeliveryEventItem] {
        latestEvents.filter { event in
            event.title.hasPrefix("系统：创建阶段 Agent")
                || event.title.hasPrefix("系统：发送任务指令")
                || event.title.contains("正在等待 Agent 回复")
                || event.title.hasPrefix("Agent：阶段回复")
        }
    }

    private var executionState: AIExecutionState {
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

    private var latestActivity: DeliveryEventItem? {
        latestEvents.last
    }

    private var visibleMessages: [AITranscriptMessage] {
        visibleEvents.compactMap { event in
            if event.title.hasPrefix("Agent："),
               event.detail.count > 200
            {
                return nil
            }
            return AITranscriptMessage(kind: kind(for: event), title: event.title, body: event.detail, footnote: event.time)
        }
    }

    private var writingStatusMessage: AITranscriptMessage? {
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

    private var artifactItems: [StageDownloadItem] {
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

    private var scrollAnchorID: String {
        let artifactPart = artifactItems.map { "\($0.title):\($0.filePath ?? "")" }.joined(separator: "|")
        return "\(executionState.label)|\(thinkingEvents.count)|\(detail?.aiRun?.deltaCount ?? 0)|\(artifactPart)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
            Text("后台 AI 会话")
                .font(.subheadline.weight(.semibold))

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    if executionState.showsSpinner {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.7)
                    } else {
                        Circle()
                            .fill(executionState.tint)
                            .frame(width: 7, height: 7)
                    }
                    Text(executionState.label)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(executionState.tint)
                    Text(latestActivity?.title ?? statusLine)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Spacer()
                    if let latestActivity {
                        Text(latestActivity.time)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))

                Divider()

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            if thinkingEvents.isEmpty && writingStatusMessage == nil && artifactItems.isEmpty {
                                AITranscriptBubble(
                                    message: AITranscriptMessage(
                                        kind: .system,
                                        title: "等待后台触发",
                                        body: "进入阶段后会自动触发后台 AI。若没有启动或上次失败，可以手动重试。",
                                        footnote: "系统"
                                    )
                                )
                            } else {
                                if !thinkingEvents.isEmpty {
                                    AIThinkingDisclosure(
                                        events: thinkingEvents,
                                        state: executionState,
                                        isExpanded: $thinkingExpanded
                                    )
                                }

                                ForEach(visibleMessages) { message in
                                    AITranscriptBubble(message: message)
                                }

                                if let statusMessage = writingStatusMessage {
                                    AITranscriptBubble(message: statusMessage)
                                }

                                if !artifactItems.isEmpty {
                                    AIArtifactBlock(viewModel: viewModel, items: artifactItems)
                                }
                            }

                            Color.clear
                                .frame(height: 1)
                                .id("conversation-bottom")
                        }
                        .padding(14)
                    }
                    .frame(height: 280)
                    .onAppear {
                        proxy.scrollTo("conversation-bottom", anchor: .bottom)
                    }
                    .onChange(of: scrollAnchorID) { _ in
                        withAnimation(.easeOut(duration: 0.18)) {
                            proxy.scrollTo("conversation-bottom", anchor: .bottom)
                        }
                    }
                }

                Divider()

                HStack(spacing: 10) {
                    Text("后台自动触发，无需输入。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if executionState == .waiting || executionState == .failed {
                        Button(executionState == .failed ? "重试后台 AI" : "触发后台 AI") {
                            viewModel.generateAIForSelectedStage()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(viewModel.isGeneratingStageAI)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
            }
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
            )
        }
    }

    private var statusLine: String {
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

    private func kind(for event: DeliveryEventItem) -> AITranscriptKind {
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
