import SwiftUI

// MARK: - Execution State

enum AIExecutionState: Equatable {
    case waiting
    case waitingFirstDelta
    case outputting
    case postProcessing
    case completed
    case failed

    var label: String {
        switch self {
        case .waiting: return "待触发"
        case .waitingFirstDelta: return "等待首包"
        case .outputting: return "运行中"
        case .postProcessing: return "后处理"
        case .completed: return "已完成"
        case .failed: return "失败"
        }
    }

    var tint: Color {
        switch self {
        case .waiting: return .secondary
        case .waitingFirstDelta: return .orange
        case .outputting: return .accentColor
        case .postProcessing: return .purple
        case .completed: return .green
        case .failed: return .red
        }
    }

    var showsSpinner: Bool {
        switch self {
        case .waitingFirstDelta, .outputting, .postProcessing: return true
        case .waiting, .completed, .failed: return false
        }
    }

    var icon: String {
        switch self {
        case .waiting: return "clock"
        case .waitingFirstDelta: return "arrow.down.circle"
        case .outputting: return "text.bubble"
        case .postProcessing: return "gearshape"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    /// Short badge text for the status header.
    var badgeText: String {
        switch self {
        case .waiting: return "待触发"
        case .waitingFirstDelta, .outputting, .postProcessing: return "运行中"
        case .completed: return "已完成"
        case .failed: return "失败"
        }
    }
}

// MARK: - Message Model

enum AITranscriptKind {
    case agent
    case system

    var icon: String {
        switch self {
        case .agent: return "sparkle"
        case .system: return "bolt.horizontal"
        }
    }

    var tint: Color {
        switch self {
        case .agent: return .accentColor
        case .system: return .secondary
        }
    }
}

struct AITranscriptMessage: Identifiable {
    let id = UUID()
    var kind: AITranscriptKind
    var title: String
    var body: String
    var footnote: String
    var artifacts: [StageDownloadItem] = []
    var isStreaming: Bool = false
    var deltaCount: Int = 0
}

// MARK: - Agent Status Header

struct AgentStatusHeader: View {
    let state: AIExecutionState
    let latestTime: String?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkle")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.accentColor)
            Text("AutoDev Agent")
                .font(.subheadline.weight(.semibold))
            Spacer()
            HStack(spacing: 5) {
                if state.showsSpinner {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.7)
                } else {
                    Circle()
                        .fill(state.tint)
                        .frame(width: 7, height: 7)
                }
                Text(state.badgeText)
                    .font(.caption.weight(.medium))
                    .foregroundColor(state.tint)
            }
            if let time = latestTime {
                Text(time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("AutoDev Agent 状态：\(state.label)")
    }
}

// MARK: - Thinking Block

struct AgentThinkingBlock: View {
    let title: String
    let events: [DeliveryEventItem]
    let state: AIExecutionState
    let durationSeconds: Int?
    @Binding var isExpanded: Bool

    private var headerLabel: String {
        let prefix = state.showsSpinner ? "\(title)思考中" : "\(title)思考完成"
        if let secs = durationSeconds {
            return "\(prefix) (\(secs)s)"
        }
        return prefix
    }

    private var trailingLabel: String {
        state.showsSpinner ? "···" : "\(events.count) 步"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    Text(headerLabel)
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text(trailingLabel)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .foregroundColor(state.showsSpinner ? .orange : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    (state.showsSpinner ? Color.orange.opacity(0.08) : Color.secondary.opacity(0.08)),
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(events) { event in
                        HStack(alignment: .firstTextBaseline, spacing: 7) {
                            thinkingStepIcon(for: event)
                            Text(simplifiedTitle(event.title))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    if state.showsSpinner {
                        HStack(spacing: 7) {
                            ProgressView()
                                .controlSize(.mini)
                                .scaleEffect(0.6)
                                .frame(width: 12, height: 12)
                            Text("等待回复…")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding(.leading, 18)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func thinkingStepIcon(for event: DeliveryEventItem) -> some View {
        if event.title.contains("等待") && state.showsSpinner {
            Text("⏳")
                .font(.caption2)
                .frame(width: 12)
        } else {
            Text("✓")
                .font(.caption2.weight(.bold))
                .foregroundColor(.green)
                .frame(width: 12)
        }
    }

    private func simplifiedTitle(_ title: String) -> String {
        let normalized = title
            .replacingOccurrences(of: "系统：", with: "")
            .replacingOccurrences(of: "Agent：", with: "")

        if normalized.contains("创建阶段 Agent") || normalized.contains("发送任务指令") {
            return "准备 \(normalized)"
        }
        if normalized.contains("等待 Agent 回复") {
            return "等待 \(normalized) 输出"
        }
        if normalized.contains("阶段回复") {
            return "接收 \(normalized) 内容"
        }
        return normalized
    }
}

// MARK: - Agent Message Bubble

struct AgentMessageBubble: View {
    @ObservedObject var viewModel: ShellViewModel
    let message: AITranscriptMessage

    var body: some View {
        if message.kind == .system {
            systemMessageView
        } else {
            agentMessageView
        }
    }

    // MARK: - System Message (compact, no avatar)

    private var systemMessageView: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
                .font(.caption)
                .foregroundColor(.orange)
            Text(message.body)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    // MARK: - Agent Message (avatar + markdown + artifacts)

    private var agentMessageView: some View {
        HStack(alignment: .top, spacing: 10) {
            agentAvatar
            VStack(alignment: .leading, spacing: 0) {
                messageHeader
                messageBody
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(nsColor: .controlBackgroundColor).opacity(0.65),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
        }
    }

    private var agentAvatar: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.12))
            Image(systemName: "sparkle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.accentColor)
        }
        .frame(width: 26, height: 26)
    }

    private var messageHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(message.title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(message.footnote)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var messageBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            if message.isStreaming {
                streamingContent
            } else {
                AgentMarkdownText(text: message.body)
            }

            if !message.artifacts.isEmpty {
                inlineArtifacts
            }
        }
    }

    private var streamingContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            AgentMarkdownText(text: message.body)

            HStack(spacing: 4) {
                Text("文件写入中...")
                    .font(.caption2.weight(.medium))
                    .foregroundColor(.accentColor)
            }

            // Blinking cursor
            Text("▊")
                .font(.subheadline)
                .foregroundColor(.accentColor)
                .opacity(0.8)
                .modifier(BlinkModifier())
        }
    }

    // MARK: - Inline Artifacts (green clickable file links)

    private var inlineArtifacts: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(message.artifacts) { item in
                HStack(spacing: 6) {
                    Image(systemName: "doc.text.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    if let path = item.filePath, !path.isEmpty {
                        Button(action: { viewModel.openStageDownload(item) }) {
                            Text(fileNameFromPath(path))
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.green)
                        }
                        .buttonStyle(.plain)
                        .handCursorOnHover()
                        .help(path)
                        .accessibilityLabel("打开文件 \(fileNameFromPath(path))")
                    } else {
                        Text(item.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - Blink Animation Modifier

private struct BlinkModifier: ViewModifier {
    @State private var visible = true

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    visible = false
                }
            }
    }
}

// MARK: - Agent Feedback Input

struct AgentFeedbackInput: View {
    @Binding var feedbackDraft: String
    let isGenerating: Bool
    let onCancel: () -> Void
    let onSubmit: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $feedbackDraft)
                .font(.callout)
                .frame(height: 52)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if feedbackDraft.isEmpty {
                        Text("描述希望调整的内容，例如「风险分析不够详细」…")
                            .font(.callout)
                            .foregroundColor(.secondary.opacity(0.45))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }
                .accessibilityLabel("调整意见输入")

            HStack(spacing: 8) {
                Spacer()
                Button("取消") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button("根据反馈重新生成") {
                    let text = feedbackDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSubmit(text)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(feedbackDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
