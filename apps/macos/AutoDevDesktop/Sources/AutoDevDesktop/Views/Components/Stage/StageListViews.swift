import SwiftUI

struct StageArtifactListView: View {
    @ObservedObject var viewModel: ShellViewModel
    let items: [DeliveryArtifactItem]

    var body: some View {
        VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
            ForEach(items) { item in
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "doc.text")
                        .foregroundColor(.green)
                        .font(.subheadline)
                    if let filePath = item.filePath, !filePath.isEmpty {
                        Text(fileNameFromPath(filePath))
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.green)
                            .underline()
                            .onTapGesture {
                                viewModel.openFilePath(filePath)
                            }
                            .handCursorOnHover()
                            .help(filePath)
                    } else {
                        Text(item.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.secondary)
                    }
                    if !item.kind.isEmpty {
                        Text(item.kind)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if item.filePath == nil || item.filePath?.isEmpty == true {
                        Text("待生成")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
