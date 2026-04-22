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

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if message.role == .ai {
                Image(systemName: "sparkles")
                    .foregroundColor(.accentColor)
                    .padding(.top, 4)
            } else {
                Image(systemName: "person.fill")
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(message.role == .ai ? "AI" : "你")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(message.role == .ai ? .accentColor : .secondary)
                    Text(message.timestamp)
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                }
                if message.isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(message.content)
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(
                        Color.accentColor.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                } else {
                    Text(message.content)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(
                            message.role == .ai ? Color.accentColor.opacity(0.08) : Color(nsColor: .controlBackgroundColor),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
