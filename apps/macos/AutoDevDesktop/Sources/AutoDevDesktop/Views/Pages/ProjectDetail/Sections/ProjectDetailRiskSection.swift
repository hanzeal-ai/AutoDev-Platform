import SwiftUI

struct ProjectDetailRiskSection: View {
    let detail: DeliveryExecutionDetail

    var body: some View {
        DashboardCard(title: "风险与阻塞") {
            VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                if detail.riskItems.isEmpty, detail.blockerReason == nil {
                    Text("暂无风险信号")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(Array(detail.riskItems.enumerated()), id: \.offset) { _, item in
                        Text("• \(item)")
                            .font(.subheadline)
                    }
                }
                if let blockerReason = detail.blockerReason {
                    KeyValueRow(key: "阻塞原因", value: blockerReason)
                }
            }
        }
    }
}
