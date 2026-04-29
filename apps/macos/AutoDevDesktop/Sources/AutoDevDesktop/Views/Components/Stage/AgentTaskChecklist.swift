import SwiftUI

/// Codex-style collapsible task checklist — completed items show green checkmark + strikethrough.
struct AgentTaskChecklist: View {
    let title: String
    let steps: [DeliveryStepProgressItem]
    @State private var isExpanded: Bool = true

    private var completedCount: Int {
        steps.filter { $0.status == .completed }.count
    }

    var body: some View {
        if steps.isEmpty { EmptyView() } else {
            VStack(alignment: .leading, spacing: 0) {
                // Header — tap to toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .foregroundColor(.secondary)
                        Text(title)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.primary)
                        Text("\(completedCount)/\(steps.count)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                            taskRow(step, index: index)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .background(
                Color(nsColor: .controlBackgroundColor).opacity(0.5),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private func taskRow(_ step: DeliveryStepProgressItem, index: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            stepIcon(step.status)
                .frame(width: 14, alignment: .center)
            stepLabel(step)
            Spacer()
        }
    }

    @ViewBuilder
    private func stepIcon(_ status: ProjectStatus) -> some View {
        switch status {
        case .completed:
            Text("✓")
                .font(.caption.weight(.bold))
                .foregroundColor(.green)
        case .running:
            Text("●")
                .font(.system(size: 8))
                .foregroundColor(.accentColor)
        case .failed, .blocked:
            Text("✕")
                .font(.caption.weight(.bold))
                .foregroundColor(.red)
        default:
            Text("○")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func stepLabel(_ step: DeliveryStepProgressItem) -> some View {
        switch step.status {
        case .completed:
            Text(step.title)
                .font(.caption)
                .strikethrough(true, color: .secondary.opacity(0.6))
                .foregroundColor(.secondary)
        case .running:
            HStack(spacing: 6) {
                Text(step.title)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.primary)
                Text("← 进行中")
                    .font(.caption2)
                    .foregroundColor(.accentColor)
            }
        case .failed, .blocked:
            HStack(spacing: 6) {
                Text(step.title)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.red)
                Text("← 失败")
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        default:
            Text(step.title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
