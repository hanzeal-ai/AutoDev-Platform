import SwiftUI

struct OverviewStatusOverviewCard: View {
    @ObservedObject var viewModel: ShellViewModel

    var body: some View {
        DashboardCard(title: "全局状态条") {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: AutoDevViewTheme.pageSpacing),
                    GridItem(.flexible(), spacing: AutoDevViewTheme.pageSpacing),
                    GridItem(.flexible(), spacing: AutoDevViewTheme.pageSpacing),
                ],
                alignment: .leading,
                spacing: AutoDevViewTheme.pageSpacing
            ) {
                StatusTile(label: "托管中", value: "\(viewModel.state.opsSnapshot.hostedSystemCount)")
                StatusTile(label: "运行中", value: "\(viewModel.state.runningProjectCount)")
                StatusTile(label: "待介入", value: "\(viewModel.state.interventionCount)")
                StatusTile(label: "阻塞中", value: "\(viewModel.state.opsSnapshot.blockedProjectCount)")
                StatusTile(label: "今日完成", value: "\(viewModel.state.opsSnapshot.completedToday)")
                StatusTile(label: "系统健康", value: viewModel.state.opsSnapshot.systemHealth)
            }
        }
    }
}
