import AppKit
import SwiftUI

struct CreationThreadRowView: View {
    let thread: CreationThreadSession
    let isSelected: Bool
    let onSelect: (UUID) -> Void
    let onRename: (UUID) -> Void
    let onArchive: (UUID) -> Void
    let onDelete: (UUID) -> Void

    var body: some View {
        Button(action: { onSelect(thread.id) }) {
            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.35))
                    .frame(width: 6, height: 6)
                    .padding(.top, 6)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(thread.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        LifecycleBadge(stage: thread.lifecycleStage)
                        if thread.linkedProjectID != nil {
                            Text("已关联")
                                .font(.caption2.weight(.medium))
                                .foregroundColor(.secondary)
                        }
                        if thread.isArchived {
                            Text("归档")
                                .font(.caption2.weight(.medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    Text(thread.lastUpdated)
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? Color.accentColor.opacity(0.14) : Color(nsColor: .controlBackgroundColor),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .opacity(thread.isArchived ? 0.75 : 1.0)
        .contextMenu {
            Button("重命名") {
                onRename(thread.id)
            }
            Button("归档") {
                onArchive(thread.id)
            }
            .disabled(thread.isArchived)
            Button("删除", role: .destructive) {
                onDelete(thread.id)
            }
        }
    }
}

struct CreationMessageRowView: View {
    let message: CreationConversationMessage
    let isLastAIMessage: Bool
    let onCopy: (() -> Void)?
    let onRetry: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @State private var webViewHeight: CGFloat = 24
    @State private var isThinkingExpanded = false
    @State private var thinkingPulse = false

    init(
        message: CreationConversationMessage,
        isLastAIMessage: Bool = false,
        onCopy: (() -> Void)? = nil,
        onRetry: (() -> Void)? = nil
    ) {
        self.message = message
        self.isLastAIMessage = isLastAIMessage
        self.onCopy = onCopy
        self.onRetry = onRetry
    }

    var body: some View {
        if message.role == .ai {
            // AI message: left-aligned with icon
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundColor(.accentColor)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("AI")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.accentColor)
                        Text(message.timestamp)
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                        Spacer()
                    }

                    aiMessageBubble
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            // User message: right-aligned bubble
            HStack {
                Spacer(minLength: 60)
                Text(message.content)
                    .font(.subheadline)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Color.accentColor.opacity(0.15),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    // MARK: - AI Message Bubble

    @ViewBuilder
    private var aiMessageBubble: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thinking block (collapsible)
            if let thinkingContent = extractThinkingContent(from: message.content) {
                thinkingBlock(content: thinkingContent)
            } else if message.isLoading && message.content.isEmpty {
                // Streaming just started — show thinking indicator
                thinkingInProgressBlock
            }

            // Main content (with thinking tags stripped)
            let displayContent = stripThinkingTags(from: message.content)
            if message.isLoading && displayContent.isEmpty {
                // Still in thinking phase — no content yet
                EmptyView()
            } else if message.isLoading {
                // Streaming in progress — show content with cursor
                ChatMarkdownWebView(
                    content: displayContent + "▍",
                    isDark: colorScheme == .dark,
                    dynamicHeight: $webViewHeight
                )
                .frame(height: max(webViewHeight, 24))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            } else if !displayContent.isEmpty {
                // Final content
                ChatMarkdownWebView(
                    content: displayContent,
                    isDark: colorScheme == .dark,
                    dynamicHeight: $webViewHeight
                )
                .frame(height: max(webViewHeight, 24))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }

            // Actions: always visible at the bottom
            if !message.isLoading && !message.content.isEmpty {
                messageActions
                    .padding(.top, 4)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
            }
        }
        .background(
            Color.accentColor.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
    }

    // MARK: - Thinking Block

    @ViewBuilder
    private func thinkingBlock(content: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isThinkingExpanded.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: isThinkingExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text("思考过程" + (isThinkingExpanded ? "（收起）" : ""))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            if isThinkingExpanded {
                Divider()
                    .padding(.horizontal, 8)
                Text(content)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineSpacing(3)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        Color(nsColor: .controlBackgroundColor).opacity(0.5)
                    )
            }
        }
    }

    @ViewBuilder
    private var thinkingInProgressBlock: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 6, height: 6)
                .opacity(thinkingPulse ? 1.0 : 0.3)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: thinkingPulse)
                .onAppear { thinkingPulse = true }
            Text("思考中...")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    // MARK: - Content Extraction

    private func extractThinkingContent(from content: String) -> String? {
        let pattern = "<thinking>([\\s\\S]*?)</thinking>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(content.startIndex..., in: content)
        guard let match = regex.firstMatch(in: content, range: range) else { return nil }
        guard let captureRange = Range(match.range(at: 1), in: content) else { return nil }
        return String(content[captureRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func stripThinkingTags(from content: String) -> String {
        let pattern = "<thinking>[\\s\\S]*?</thinking>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return content }
        let range = NSRange(content.startIndex..., in: content)
        return regex.stringByReplacingMatches(in: content, range: range, withTemplate: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @ViewBuilder
    private var messageActions: some View {
        HStack(spacing: 2) {
            if message.role == .ai && isLastAIMessage, let onRetry {
                actionButton(icon: "arrow.counterclockwise", action: onRetry)
            }
            actionButton(icon: "doc.on.doc", action: { copyMessage() })
        }
    }

    private func actionButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 28, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func copyMessage() {
        if let onCopy {
            onCopy()
        } else {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(message.content, forType: .string)
        }
    }
}
