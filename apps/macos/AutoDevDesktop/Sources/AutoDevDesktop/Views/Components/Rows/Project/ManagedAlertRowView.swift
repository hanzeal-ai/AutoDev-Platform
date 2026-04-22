import SwiftUI

struct ManagedAlertRowView: View {
    let alert: ManagedAlertItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(alert.level.color)
                .frame(width: 8, height: 8)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 3) {
                Text(alert.title)
                    .font(.subheadline.weight(.semibold))
                Text(alert.projectName)
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
                Text(alert.reason)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(alert.level.rawValue)
                    .font(.caption.weight(.medium))
                    .foregroundColor(alert.level.color)
                Text(alert.nextAction)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}
