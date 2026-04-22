import SwiftUI

struct ReportSectionView: View {
    let title: String
    let text: String
    let referenceKey: String?
    let onInsertReference: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(text)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            guard let referenceKey else { return }
            onInsertReference?("#\(referenceKey)")
        }
    }
}

struct ReportListSectionView: View {
    let title: String
    let items: [String]
    let referenceKey: String?
    let onInsertReference: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    Text("• \(item)")
                        .font(.subheadline)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            guard let referenceKey else { return }
            onInsertReference?("#\(referenceKey)")
        }
    }
}
