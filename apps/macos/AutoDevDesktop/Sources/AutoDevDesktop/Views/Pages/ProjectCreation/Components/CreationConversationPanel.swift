import SwiftUI

struct CreationConversationPanel: View {
    let selectedThreadTitle: String?
    let selectedThreadStage: DeliveryLifecycleStage
    let selectedMaterials: [CreationMaterialItem]
    let selectedMessages: [CreationConversationMessage]
    let selectedThreadID: UUID?
    let isSendingMessage: Bool
    let creationInputDraft: Binding<String>
    let creationInputInsertionRequest: Binding<CreationInputInsertionRequest?>
    let onImportMaterials: () -> Void
    let onRemoveMaterial: (UUID) -> Void
    let onSendMessage: (UUID, String) -> Void
    var onRetryLastMessage: ((UUID) -> Void)? = nil
    var onStopGenerating: (() -> Void)? = nil
    var onQuickPrompt: ((String) -> Void)? = nil

    var body: some View {
        DashboardCard(title: "AI 立项对话") {
            VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
                HStack {
                    if let selectedThreadTitle = selectedThreadTitle {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(selectedThreadTitle)
                                    .font(.headline.weight(.semibold))
                                LifecycleBadge(stage: selectedThreadStage)
                            }
                        }
                    } else {
                        Text("请选择一个线程开始")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }

                CreationMaterialsPanel(
                    materials: selectedMaterials,
                    onImportMaterials: onImportMaterials,
                    onRemoveMaterial: onRemoveMaterial
                )

                Divider()

                messageList

                Divider()

                CreationComposer(
                    threadID: selectedThreadID,
                    isSending: isSendingMessage,
                    draft: creationInputDraft,
                    insertionRequest: creationInputInsertionRequest,
                    stage: selectedThreadStage,
                    onSend: { threadID, value in
                        onSendMessage(threadID, value)
                    },
                    onStop: onStopGenerating
                )
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    // MARK: - Message List with Smart Scrolling

    @ViewBuilder
    private var messageList: some View {
        if selectedMessages.isEmpty {
            emptyStateView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: AutoDevViewTheme.compactSpacing) {
                        ForEach(Array(selectedMessages.enumerated()), id: \.element.id) { index, message in
                            let isLastAI = isLastAIMessage(at: index)
                            CreationMessageRowView(
                                message: message,
                                isLastAIMessage: isLastAI,
                                onRetry: isLastAI ? {
                                    if let threadID = selectedThreadID {
                                        onRetryLastMessage?(threadID)
                                    }
                                } : nil
                            )
                            .id(message.id)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: .infinity)
                .onChange(of: selectedMessages.count) { _ in
                    // Auto-scroll to bottom when new messages arrive
                    if let lastID = selectedMessages.last?.id {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: selectedMessages.last?.content) { _ in
                    // Also scroll during streaming content updates
                    if let lastID = selectedMessages.last?.id {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Empty State Guide

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 28))
                .foregroundColor(.accentColor.opacity(0.6))
            Text("开始你的项目构想")
                .font(.headline)
                .foregroundColor(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                quickPromptCard(
                    icon: "💡",
                    title: "描述产品想法",
                    prompt: "我想做一个"
                )
                quickPromptCard(
                    icon: "📋",
                    title: "从需求出发",
                    prompt: "我的核心需求是"
                )
                quickPromptCard(
                    icon: "🔍",
                    title: "分析竞品差异",
                    prompt: "市面上已有类似产品，我想做的差异化是"
                )
                quickPromptCard(
                    icon: "🎯",
                    title: "明确目标用户",
                    prompt: "我的目标用户是"
                )
            }
            .padding(.horizontal, 20)
            Spacer()
        }
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity)
    }

    private func quickPromptCard(icon: String, title: String, prompt: String) -> some View {
        Button(action: { onQuickPrompt?(prompt) }) {
            VStack(alignment: .leading, spacing: 4) {
                Text(icon)
                    .font(.title3)
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func isLastAIMessage(at index: Int) -> Bool {
        guard selectedMessages[index].role == .ai else { return false }
        let remaining = selectedMessages.suffix(from: index + 1)
        return !remaining.contains(where: { $0.role == .ai && !$0.isLoading })
    }
}
