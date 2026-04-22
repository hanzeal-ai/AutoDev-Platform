import SwiftUI

struct ProjectDetailEventSection: View {
    let detail: DeliveryExecutionDetail

    var body: some View {
        DashboardCard(title: "事件流") {
            VStack(spacing: AutoDevViewTheme.compactSpacing) {
                ForEach(detail.events) { event in
                    HStack(alignment: .top, spacing: 8) {
                        Text(event.time)
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                            .frame(width: 42, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title)
                                .font(.subheadline.weight(.semibold))
                            Text(event.detail)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                if detail.events.isEmpty {
                    Text("暂无事件")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                }
            }
        }
    }
}
