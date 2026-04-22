import SwiftUI

struct BlockedProjectRowView: View {
    let project: DeliveryProjectItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(project.status.color)
                .frame(width: 8, height: 8)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 3) {
                Text(project.title)
                    .font(.subheadline.weight(.semibold))
                Text(project.blockReason ?? "执行受阻")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                Text(project.nextAction)
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(project.updateTime)
                .font(.caption.monospaced())
                .foregroundColor(.secondary)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}
