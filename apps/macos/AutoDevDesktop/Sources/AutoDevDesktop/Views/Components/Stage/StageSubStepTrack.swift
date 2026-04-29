import SwiftUI

/// Horizontal pill track for navigating sub-steps within a stage.
/// Visually matches the lifecycle track style.
struct StageSubStepTrack: View {
    let subSteps: [DeliverySubStepItem]
    let activeSubStep: String
    let onSelect: (String) -> Void
    let isStepDisabled: (DeliverySubStepItem) -> Bool
    let onDisabledSelect: (DeliverySubStepItem) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(subSteps.enumerated()), id: \.element.id) { index, step in
                let isActive = step.key == activeSubStep
                let isDisabled = isStepDisabled(step)

                HStack(spacing: 6) {
                    Circle()
                        .fill(stepIndicatorColor(step: step, isDisabled: isDisabled))
                        .frame(width: 7, height: 7)
                    Text(step.label)
                        .font(.caption.weight(.medium))
                        .foregroundColor(stepTextColor(isActive: isActive, isDisabled: isDisabled))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(backgroundColor(isActive: isActive, isDisabled: isDisabled))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .stroke(borderColor(isActive: isActive, isDisabled: isDisabled), lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 999, style: .continuous))
                .onTapGesture {
                    if isDisabled {
                        onDisabledSelect(step)
                    } else if !isActive {
                        onSelect(step.key)
                    }
                }
                .accessibilityLabel("\(step.label)\(isActive ? "，正在查看" : "")\(isDisabled ? "，当前不可用" : "")")
                .help(helpText(for: step, isActive: isActive, isDisabled: isDisabled))
                .modifier(isDisabled ? AnyViewModifier(DisabledCursorOnHover()) : AnyViewModifier(HandCursorOnHover()))

                if index < subSteps.count - 1 {
                    Capsule(style: .circular)
                        .fill(step.hasContent ? Color.accentColor.opacity(0.6) : Color.secondary.opacity(0.2))
                        .frame(width: 14, height: 3)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func stepIndicatorColor(step: DeliverySubStepItem, isDisabled: Bool) -> Color {
        if isDisabled {
            return Color.secondary.opacity(0.22)
        }
        return step.hasContent ? Color.accentColor : Color.secondary.opacity(0.35)
    }

    private func stepTextColor(isActive: Bool, isDisabled: Bool) -> Color {
        if isDisabled {
            return .secondary.opacity(0.6)
        }
        return isActive ? .primary : .secondary
    }

    private func backgroundColor(isActive: Bool, isDisabled: Bool) -> Color {
        if isDisabled {
            return Color.secondary.opacity(0.06)
        }
        return isActive ? Color.accentColor.opacity(0.16) : Color(nsColor: .controlBackgroundColor)
    }

    private func borderColor(isActive: Bool, isDisabled: Bool) -> Color {
        if isDisabled {
            return Color.secondary.opacity(0.1)
        }
        return isActive ? Color.accentColor.opacity(0.45) : Color.clear
    }

    private func helpText(for step: DeliverySubStepItem, isActive: Bool, isDisabled: Bool) -> String {
        if isDisabled {
            return "请先完成页面地图"
        }
        if isActive {
            return ""
        }
        return "点击查看\(step.label)"
    }
}

private struct AnyViewModifier: ViewModifier {
    private let apply: (Content) -> AnyView

    init<M: ViewModifier>(_ modifier: M) {
        self.apply = { AnyView($0.modifier(modifier)) }
    }

    func body(content: Content) -> some View {
        apply(content)
    }
}
