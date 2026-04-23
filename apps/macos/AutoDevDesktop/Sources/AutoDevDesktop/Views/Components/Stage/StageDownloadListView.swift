import SwiftUI

struct StageDownloadListView: View {
    @ObservedObject var viewModel: ShellViewModel
    let items: [StageDownloadItem]

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                ForEach(items) { item in
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: "doc.text")
                            .foregroundColor(item.availability == .pending ? .secondary : .green)
                            .font(.subheadline)
                        if let filePath = item.filePath, !filePath.isEmpty, item.availability != .pending {
                            Text(fileNameFromPath(filePath))
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.green)
                                .underline()
                                .onTapGesture {
                                    viewModel.openStageDownload(item)
                                }
                                .handCursorOnHover()
                                .help(filePath)
                        } else {
                            Text(item.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.secondary)
                        }
                        Text(item.category.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        if item.availability == .pending {
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
}
