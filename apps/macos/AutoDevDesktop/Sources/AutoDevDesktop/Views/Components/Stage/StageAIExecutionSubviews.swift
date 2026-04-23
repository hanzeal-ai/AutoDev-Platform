import SwiftUI

enum AIExecutionState {
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

struct AITranscriptMessage: Identifiable {
    let id = UUID()
    var kind: AITranscriptKind
    var title: String
    var body: String
    var footnote: String
}

enum AITranscriptKind {
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

struct AIThinkingDisclosure: View {
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

struct AIArtifactBlock: View {
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

struct AITranscriptBubble: View {
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
