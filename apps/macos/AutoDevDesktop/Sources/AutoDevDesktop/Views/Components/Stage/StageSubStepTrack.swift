import SwiftUI

/// Horizontal pill track for navigating sub-steps within a stage.
/// Visually matches the lifecycle track style.
struct StageSubStepTrack: View {
    let subSteps: [DeliverySubStepItem]
    let activeSubStep: String
    let onSelect: (String) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(subSteps.enumerated()), id: \.element.id) { index, step in
                let isActive = step.key == activeSubStep

                HStack(spacing: 6) {
                    Circle()
                        .fill(step.hasContent ? Color.accentColor : Color.secondary.opacity(0.35))
                        .frame(width: 7, height: 7)
                    Text(step.label)
                        .font(.caption.weight(.medium))
                        .foregroundColor(isActive ? .primary : .secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(isActive ? Color.accentColor.opacity(0.16) : Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .stroke(isActive ? Color.accentColor.opacity(0.45) : Color.clear, lineWidth: 1)
                )
                .onTapGesture {
                    if !isActive { onSelect(step.key) }
                }
                .accessibilityLabel("\(step.label)\(isActive ? "，正在查看" : "")")
                .help(!isActive ? "点击查看\(step.label)" : "")

                if index < subSteps.count - 1 {
                    Capsule(style: .circular)
                        .fill(step.hasContent ? Color.accentColor.opacity(0.6) : Color.secondary.opacity(0.2))
                        .frame(width: 14, height: 3)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
