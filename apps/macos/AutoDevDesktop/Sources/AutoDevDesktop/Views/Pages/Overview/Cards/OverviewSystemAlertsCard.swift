import SwiftUI

struct OverviewSystemAlertsCard: View {
    @ObservedObject var viewModel: ShellViewModel

    var body: some View {
        DashboardCard(title: "系统告警") {
            LazyVStack(spacing: AutoDevViewTheme.compactSpacing) {
                if viewModel.state.blockedProjects.isEmpty && viewModel.state.managedAlerts.isEmpty {
                    Text("暂无系统告警")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(viewModel.state.blockedProjects) { project in
                        BlockedProjectRowView(project: project)
                    }

                    ForEach(viewModel.state.managedAlerts) { alert in
                        ManagedAlertRowView(alert: alert)
                    }
                }
            }
        }
    }
}
