import SwiftUI

struct DashboardCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
            Text(title)
                .font(.headline)
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(nsColor: .textBackgroundColor),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }
}

struct MeterBar: View {
    let value: Double

    var body: some View {
        GeometryReader { proxy in
            let clampedValue = min(max(value, 0), 1)
            ZStack(alignment: .leading) {
                Capsule(style: .circular)
                    .fill(Color.secondary.opacity(0.16))
                Capsule(style: .circular)
                    .fill(Color.accentColor)
                    .frame(width: max(6, proxy.size.width * clampedValue))
            }
        }
        .frame(height: 8)
    }
}

struct LifecycleBadge: View {
    let stage: DeliveryLifecycleStage

    var body: some View {
        Text(stage.rawValue)
            .font(.caption2.weight(.semibold))
            .foregroundColor(.accentColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.14), in: Capsule())
    }
}

struct LifecycleTrack: View {
    let current: DeliveryLifecycleStage
    let compact: Bool

    var body: some View {
        Group {
            if compact {
                HStack(spacing: 4) {
                    ForEach(DeliveryLifecycleStage.allCases) { stage in
                        Capsule(style: .circular)
                            .fill(stage.order <= current.order ? Color.accentColor : Color.secondary.opacity(0.22))
                            .frame(width: 12, height: 4)
                    }
                }
            } else {
                HStack(spacing: 6) {
                    ForEach(DeliveryLifecycleStage.allCases) { stage in
                        Text(stage.rawValue)
                            .font(.caption.weight(.medium))
                            .foregroundColor(stage.order <= current.order ? .primary : .secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                stage.order <= current.order ? Color.accentColor.opacity(0.14) : Color(nsColor: .controlBackgroundColor),
                                in: Capsule()
                            )
                    }
                }
            }
        }
    }
}
