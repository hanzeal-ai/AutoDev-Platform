import SwiftUI

struct StageDownloadListView: View {
    @ObservedObject var viewModel: ShellViewModel
    let items: [StageDownloadItem]

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                ForEach(items) { item in
                    HStack(alignment: .center, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.subheadline.weight(.medium))
                            Text(item.category.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if let filePath = item.filePath, !filePath.isEmpty {
                                Text(filePath)
                                    .font(.caption2.monospaced())
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        switch item.availability {
                        case .ready:
                            Button("下载") {
                                viewModel.openStageDownload(item)
                            }
                            .buttonStyle(.bordered)
                        case .viewOnly:
                            Button("查看") {
                                viewModel.openStageDownload(item)
                            }
                            .buttonStyle(.bordered)
                        case .pending:
                            Text("待生成")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(nsColor: .controlBackgroundColor), in: Capsule())
                        }
                    }
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }
}
