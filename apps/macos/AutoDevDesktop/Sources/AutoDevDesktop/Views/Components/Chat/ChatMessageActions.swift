import AppKit
import SwiftUI

struct ChatMessageActions: View {
    let message: CreationConversationMessage
    let isHovered: Bool
    let isLastAIMessage: Bool
    let onCopy: () -> Void
    let onRetry: (() -> Void)?

    var body: some View {
        if isHovered && !message.isLoading {
            HStack(spacing: 4) {
                actionButton(icon: "doc.on.doc", label: "复制", action: onCopy)
                if message.role == .ai && isLastAIMessage, let onRetry {
                    actionButton(icon: "arrow.counterclockwise", label: "重试", action: onRetry)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 0.5)
            )
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
    }

    private func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            // Individual button hover effect handled by buttonStyle
        }
    }

}

// MARK: - Hover-tracking container

struct HoverableMessageRow<Content: View>: View {
    let content: Content
    let actions: () -> AnyView

    @State private var isHovered = false

    init(
        @ViewBuilder content: () -> Content,
        @ViewBuilder actions: @escaping () -> AnyView
    ) {
        self.content = content()
        self.actions = actions
    }

    var body: some View {
        content
            .overlay(alignment: .topTrailing) {
                if isHovered {
                    actions()
                        .padding(.top, -4)
                        .padding(.trailing, 4)
                }
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
    }
}
