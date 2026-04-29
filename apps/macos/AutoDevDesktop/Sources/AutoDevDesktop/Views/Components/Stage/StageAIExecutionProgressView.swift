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
        VStack(alignment: .leading, spacing: 0) {
            AgentStatusHeader(
                state: helper.executionState,
                latestTime: helper.latestActivity?.time
            )

            Divider()

            transcriptContent

            Divider()

            actionArea
        }
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
        )
    }

    // MARK: - Transcript

    private var transcriptContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Empty state
                    if helper.thinkingEvents.isEmpty && helper.conversationMessages.isEmpty {
                        emptyStateMessage
                    } else {
                        // Thinking block
                        if !helper.thinkingEvents.isEmpty {
                            AgentThinkingBlock(
                                title: helper.thinkingSectionTitle,
                                events: helper.thinkingEvents,
                                state: helper.executionState,
                                durationSeconds: helper.thinkingDurationSeconds,
                                isExpanded: $thinkingExpanded
                            )
                        }

                        // Conversation messages
                        ForEach(helper.conversationMessages) { message in
                            AgentMessageBubble(viewModel: viewModel, message: message)
                        }

                        // Task checklist
                        if !helper.taskItems.isEmpty {
                            AgentTaskChecklist(title: helper.taskSectionTitle, steps: helper.taskItems)
                        }
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("conversation-bottom")
                }
                .padding(14)
            }
            .frame(height: 300)
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

    private var emptyStateMessage: some View {
        HStack(spacing: 6) {
            Image(systemName: "bolt.horizontal")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("进入阶段后将自动触发后台 AI。若未启动或上次失败，可手动触发。")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    // MARK: - Action Area

    private var actionArea: some View {
        VStack(spacing: 0) {
            if isShowingFeedback {
                AgentFeedbackInput(
                    feedbackDraft: $feedbackDraft,
                    isGenerating: viewModel.isGeneratingStageAI,
                    onCancel: {
                        withAnimation(.easeOut(duration: 0.15)) {
                            isShowingFeedback = false
                            feedbackDraft = ""
                        }
                    },
                    onSubmit: { feedback in
                        withAnimation(.easeOut(duration: 0.15)) {
                            isShowingFeedback = false
                            feedbackDraft = ""
                        }
                        viewModel.clearSelectedStageUI()
                        viewModel.generateAIForSelectedStage(feedback: feedback.isEmpty ? nil : feedback)
                    }
                )
                Divider()
            }
            actionBar
        }
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Spacer()
            if helper.executionState == .completed {
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        isShowingFeedback = true
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("不满意？调整并重新生成")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .handCursorOnHover()
                .disabled(viewModel.isGeneratingStageAI)
            } else if helper.executionState == .waiting || helper.executionState == .failed {
                Button(helper.executionState == .failed ? "重试后台 AI" : "触发后台 AI") {
                    viewModel.generateAIForSelectedStage()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(viewModel.isGeneratingStageAI)
            } else {
                Text("后台 AI 执行中…")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}
