import SwiftUI

struct StageStepProgressBar: View {
    let steps: [DeliveryStepProgressItem]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                HStack(spacing: 6) {
                    stepIcon(for: step.status)
                    Text(step.title)
                        .font(.caption)
                        .foregroundColor(stepTextColor(for: step.status))
                        .lineLimit(1)
                }

                if index < steps.count - 1 {
                    stepConnector(from: step.status)
                }
            }
        }
    }

    @ViewBuilder
    private func stepIcon(for status: ProjectStatus) -> some View {
        switch status {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.green)
        case .running:
            Image(systemName: "circle.fill")
                .font(.caption2)
                .foregroundColor(.accentColor)
        case .awaitingConfirmation:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption)
                .foregroundColor(.orange)
        case .blocked, .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.caption)
                .foregroundColor(.red)
        default:
            Image(systemName: "circle")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private func stepTextColor(for status: ProjectStatus) -> Color {
        switch status {
        case .completed:
            return .green
        case .running:
            return .primary
        case .awaitingConfirmation:
            return .orange
        case .blocked, .failed:
            return .red
        default:
            return .secondary
        }
    }

    private func stepConnector(from status: ProjectStatus) -> some View {
        Rectangle()
            .fill(status == .completed ? Color.green.opacity(0.5) : Color.secondary.opacity(0.3))
            .frame(width: 16, height: 1)
            .padding(.horizontal, 4)
    }
}
