import SwiftUI

struct StageAIExecutionProgressView: View {
    @ObservedObject var viewModel: ShellViewModel
    let stage: DeliveryLifecycleStage
    let detail: DeliveryExecutionDetail?
    let downloads: [StageDownloadItem]
    @State private var thinkingExpanded = false
    @State private var isShowingFeedback = false
    @State private var feedbackDraft = ""

    private var helper: AIExecutionStateHelper {
        AIExecutionStateHelper(detail: detail, stage: stage, downloads: downloads)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
            Text("后台 AI 会话")
                .font(.subheadline.weight(.semibold))

            VStack(alignment: .leading, spacing: 0) {
                executionStatusBar

                Divider()

                transcriptContent

                Divider()

                VStack(spacing: 0) {
                    if isShowingFeedback {
                        feedbackPanel
                        Divider()
                    }
                    actionBar
                }
            }
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
            )
        }
    }

    // MARK: - Status Bar

    private var executionStatusBar: some View {
        HStack(spacing: 8) {
            if helper.executionState.showsSpinner {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.7)
            } else {
                Image(systemName: helper.executionState.icon)
                    .foregroundColor(helper.executionState.tint)
                    .font(.caption)
            }
            Text(helper.executionState.label)
                .font(.caption.weight(.semibold))
                .foregroundColor(helper.executionState.tint)
            Text(helper.latestActivity?.title ?? helper.statusLine)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            Spacer()
            if let latestActivity = helper.latestActivity {
                Text(latestActivity.time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("AI 执行状态：\(helper.executionState.label)")
    }

    // MARK: - Transcript

    private var transcriptContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if helper.thinkingEvents.isEmpty && helper.writingStatusMessage == nil && helper.artifactItems.isEmpty {
                        AITranscriptBubble(
                            message: AITranscriptMessage(
                                kind: .system,
                                title: "等待后台触发",
                                body: "进入阶段后会自动触发后台 AI。若没有启动或上次失败，可以手动重试。",
                                footnote: "系统"
                            )
                        )
                    } else {
                        if !helper.thinkingEvents.isEmpty {
                            AIThinkingDisclosure(
                                events: helper.thinkingEvents,
                                state: helper.executionState,
                                isExpanded: $thinkingExpanded
                            )
                        }

                        ForEach(helper.visibleMessages) { message in
                            AITranscriptBubble(message: message)
                        }

                        if let statusMessage = helper.writingStatusMessage {
                            AITranscriptBubble(message: statusMessage)
                        }

                        if !helper.artifactItems.isEmpty {
                            AIArtifactBlock(viewModel: viewModel, items: helper.artifactItems)
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
            .onChange(of: helper.scrollAnchorID) { _ in
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo("conversation-bottom", anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Feedback Panel

    private var feedbackPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("调整意见")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            TextEditor(text: $feedbackDraft)
                .font(.callout)
                .frame(height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if feedbackDraft.isEmpty {
                        Text("描述你希望调整的内容，例如「风险分析不够详细」「增加测试覆盖率要求」…")
                            .font(.callout)
                            .foregroundColor(.secondary.opacity(0.5))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }
                .accessibilityLabel("调整意见输入")
            HStack(spacing: 8) {
                Spacer()
                Button("取消") {
                    withAnimation(.easeOut(duration: 0.15)) {
                        isShowingFeedback = false
                        feedbackDraft = ""
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button("根据反馈重新生成") {
                    let feedback = feedbackDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    withAnimation(.easeOut(duration: 0.15)) {
                        isShowingFeedback = false
                        feedbackDraft = ""
                    }
                    viewModel.generateAIForSelectedStage(feedback: feedback.isEmpty ? nil : feedback)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(feedbackDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isGeneratingStageAI)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 10) {
            Text("后台自动触发，无需输入。")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            if helper.executionState == .completed {
                Button("不满意，调整") {
                    withAnimation(.easeOut(duration: 0.15)) {
                        isShowingFeedback = true
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.isGeneratingStageAI)

                Button("重新生成") {
                    viewModel.generateAIForSelectedStage()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(viewModel.isGeneratingStageAI)
            } else if helper.executionState == .waiting || helper.executionState == .failed {
                Button(helper.executionState == .failed ? "重试后台 AI" : "触发后台 AI") {
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
}
