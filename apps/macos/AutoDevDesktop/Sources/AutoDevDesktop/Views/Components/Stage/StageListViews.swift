import SwiftUI

struct StageArtifactListView: View {
    let items: [DeliveryArtifactItem]

    var body: some View {
        VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(item.name)
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(item.kind)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                    }

                    HStack(alignment: .top, spacing: 12) {
                        Text(item.updatedAt)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if let filePath = item.filePath, !filePath.isEmpty {
                            Text(filePath)
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
}

struct StageProgressListView: View {
    let items: [DeliveryStepProgressItem]

    var body: some View {
        VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
            ForEach(items) { item in
                HStack(alignment: .center, spacing: 10) {
                    Circle()
                        .fill(item.status.color)
                        .frame(width: 8, height: 8)
                    Text(item.title)
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(item.status.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(item.status.color)
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
}

struct StageBulletsView: View {
    let items: [String]

    var body: some View {
        let compact = AutoDevTextSupport.compactItems(items.map(Optional.some))
        VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
            ForEach(Array(compact.enumerated()), id: \.offset) { _, item in
                Text("• \(item)")
                    .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StageLabeledListView: View {
    let title: String
    let items: [String]

    var body: some View {
        let compact = AutoDevTextSupport.compactItems(items.map(Optional.some))
        VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
            if !compact.isEmpty {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                StageBulletsView(items: compact)
            }
        }
    }
}
