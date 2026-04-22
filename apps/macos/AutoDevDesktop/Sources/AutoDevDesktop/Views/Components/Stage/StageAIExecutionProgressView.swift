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
        }
    }

    private var thinkingEvents: [DeliveryEventItem] {
        latestEvents.filter { event in
            event.title.hasPrefix("系统：创建阶段 Agent")
                || event.title.hasPrefix("系统：发送任务指令")
                || event.title.contains("正在等待 Agent 回复")
        }
    }

    private var hasRealExecutionTrace: Bool {
        guard let detail else { return false }
        return detail.inputContexts.contains { $0.contains("真实 AI：") }
            || detail.events.contains { $0.title.contains("后台 AI") }
            || detail.events.contains { $0.title.hasPrefix("系统：") }
            || detail.events.contains { $0.title.hasPrefix("Agent：") }
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
        visibleEvents.map { event in
            AITranscriptMessage(kind: kind(for: event), title: event.title, body: event.detail, footnote: event.time)
        }
    }

    private var artifactItems: [StageDownloadItem] {
        downloads.filter { item in
            item.filePath?.isEmpty == false && item.availability != .pending
        }
    }

    private var scrollAnchorID: String {
        let messagePart = visibleMessages.map { "\($0.title):\($0.body.count)" }.joined(separator: "|")
        let artifactPart = artifactItems.map { "\($0.title):\($0.filePath ?? "")" }.joined(separator: "|")
        return "\(executionState.label)|\(thinkingEvents.count)|\(messagePart)|\(artifactPart)"
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
                            if thinkingEvents.isEmpty && visibleMessages.isEmpty && artifactItems.isEmpty {
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

private enum AIExecutionState {
    case waiting
    case waitingFirstDelta
    case outputting
    case postProcessing
    case completed
    case failed

    var label: String {
        switch self {
        case .waiting:
            return "待触发"
        case .waitingFirstDelta:
            return "等待首包"
        case .outputting:
            return "输出中"
        case .postProcessing:
            return "后处理"
        case .completed:
            return "已完成"
        case .failed:
            return "失败"
        }
    }

    var tint: Color {
        switch self {
        case .waiting:
            return .secondary
        case .waitingFirstDelta:
            return .orange
        case .outputting:
            return .accentColor
        case .postProcessing:
            return .purple
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }

    var showsSpinner: Bool {
        switch self {
        case .waitingFirstDelta, .outputting, .postProcessing:
            return true
        case .waiting, .completed, .failed:
            return false
        }
    }
}

private struct AITranscriptMessage: Identifiable {
    var id: String { "\(title)-\(footnote)-\(body.count)" }
    var kind: AITranscriptKind
    var title: String
    var body: String
    var footnote: String
}

private struct AIThinkingDisclosure: View {
    let events: [DeliveryEventItem]
    let state: AIExecutionState
    @Binding var isExpanded: Bool

    private var elapsedLabel: String {
        state.showsSpinner ? "处理中" : "已处理"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 7) {
                    Text(elapsedLabel)
                        .font(.caption.weight(.semibold))
                    Text("\(events.count) 条")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    Spacer()
                }
                .foregroundColor(state.showsSpinner ? .orange : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    (state.showsSpinner ? Color.orange.opacity(0.10) : Color.secondary.opacity(0.10)),
                    in: Capsule()
                )
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(events) { event in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(Color.secondary.opacity(0.35))
                                .frame(width: 6, height: 6)
                                .padding(.top, 7)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 8) {
                                    Text(event.title)
                                        .font(.caption.weight(.semibold))
                                    Text(event.time)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                if !event.detail.isEmpty {
                                    Text(event.detail)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                    }
                }
                .padding(.leading, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AIArtifactBlock: View {
    @ObservedObject var viewModel: ShellViewModel
    let items: [StageDownloadItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(items.count) 个文件已输出")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }

            ForEach(items) { item in
                HStack(spacing: 10) {
                    Image(systemName: "doc.text")
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                            .font(.subheadline.weight(.medium))
                        if let path = item.filePath {
                            Text(path)
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    Button("查看") {
                        viewModel.openStageDownload(item)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(nsColor: .controlBackgroundColor).opacity(0.72),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
    }
}

private enum AITranscriptKind {
    case system
    case thinking
    case loading
    case output
    case file

    var icon: String {
        switch self {
        case .system:
            return "bolt.horizontal"
        case .thinking:
            return "brain.head.profile"
        case .loading:
            return "ellipsis.message"
        case .output:
            return "text.bubble"
        case .file:
            return "doc.text"
        }
    }

    var tint: Color {
        switch self {
        case .system:
            return .secondary
        case .thinking:
            return .purple
        case .loading:
            return .orange
        case .output:
            return .accentColor
        case .file:
            return .green
        }
    }
}

private struct AITranscriptBubble: View {
    let message: AITranscriptMessage

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(message.kind.tint.opacity(0.14))
                    Image(systemName: message.kind.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(message.kind.tint)
                }
                .frame(width: 26, height: 26)
            }
            .frame(width: 30)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(message.title)
                        .font(.subheadline.weight(.semibold))
                    Text(message.footnote)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                }

                Text(message.body)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineSpacing(3)
                    .textSelection(.enabled)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(nsColor: .controlBackgroundColor).opacity(0.72),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
        }
    }
}
