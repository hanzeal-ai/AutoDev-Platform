import SwiftUI

struct OverviewRunningQueueCard: View {
    @ObservedObject var viewModel: ShellViewModel

    var body: some View {
        DashboardCard(title: "运行队列") {
            VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
                HStack {
                    Spacer()
                    Button("查看全部") {
                        viewModel.openProjectLibrary()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if viewModel.state.runningQueueProjects.isEmpty {
                    Text("暂无")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                } else {
                    LazyVStack(spacing: AutoDevViewTheme.compactSpacing) {
                        ForEach(viewModel.state.runningQueueProjects) { project in
                            ProjectRowView(viewModel: viewModel, project: project, source: .overview)
                        }
                    }
                }
            }
        }
    }
}
