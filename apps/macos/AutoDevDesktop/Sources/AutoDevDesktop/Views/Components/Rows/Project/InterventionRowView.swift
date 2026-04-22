import SwiftUI

struct InterventionRowView: View {
    let item: InterventionItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(item.priority.color)
                .frame(width: 8, height: 8)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                Text(item.projectName)
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
                Text(item.reason)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(item.priority.rawValue)
                    .font(.caption.weight(.medium))
                    .foregroundColor(item.priority.color)
                Text(item.nextAction)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}
