import SwiftUI

struct CreationMaterialsPanel: View {
    let materials: [CreationMaterialItem]
    let onImportMaterials: () -> Void
    let onRemoveMaterial: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("参考资料")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: onImportMaterials) {
                    Label("上传资料", systemImage: "paperclip")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if !materials.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(materials) { material in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Image(systemName: "doc.text")
                                        .foregroundColor(.accentColor)
                                    Text(material.name)
                                        .font(.caption.weight(.semibold))
                                        .lineLimit(1)
                                }
                                Text("\(material.typeHint) · \(material.sizeHint)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                HStack(spacing: 6) {
                                    Text(material.status.rawValue)
                                        .font(.caption2)
                                        .foregroundColor(material.status == .analyzed ? .green : .orange)
                                    Spacer(minLength: 2)
                                    Button(action: { onRemoveMaterial(material.id) }) {
                                        Image(systemName: "xmark.circle.fill")
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundColor(.secondary)
                                }
                            }
                            .padding(8)
                            .frame(width: 220, alignment: .leading)
                            .background(
                                Color(nsColor: .controlBackgroundColor),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                        }
                    }
                    .padding(.vertical, 1)
                }
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .frame(height: 44)
                    .overlay(
                        HStack(spacing: 6) {
                            Image(systemName: "tray.and.arrow.down")
                            Text("上传需求文档、竞品资料、约束说明")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    )
            }
        }
    }
}
