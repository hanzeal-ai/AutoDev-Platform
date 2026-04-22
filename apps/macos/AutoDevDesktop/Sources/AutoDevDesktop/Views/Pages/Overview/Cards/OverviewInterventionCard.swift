import SwiftUI

struct OverviewInterventionCard: View {
    @ObservedObject var viewModel: ShellViewModel

    var body: some View {
        DashboardCard(title: "待你处理") {
            LazyVStack(spacing: AutoDevViewTheme.compactSpacing) {
                if viewModel.state.interventions.isEmpty {
                    Text("暂无")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                } else {
                    ForEach(viewModel.state.interventions) { item in
                        InterventionRowView(item: item)
                    }
                }
            }
        }
    }
}
