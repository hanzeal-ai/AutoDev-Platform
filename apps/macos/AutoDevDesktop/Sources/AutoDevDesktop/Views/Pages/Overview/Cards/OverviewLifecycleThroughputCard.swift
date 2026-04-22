import SwiftUI

struct OverviewLifecycleThroughputCard: View {
    @ObservedObject var viewModel: ShellViewModel

    var body: some View {
        DashboardCard(title: "生命周期与吞吐") {
            VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
                HStack(alignment: .top, spacing: AutoDevViewTheme.pageSpacing) {
                    VStack(spacing: AutoDevViewTheme.compactSpacing) {
                        ForEach(viewModel.state.lifecycleDistribution) { stage in
                            HStack {
                                Text(stage.stage.rawValue)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(stage.count)")
                                    .font(.headline.monospaced())
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                    VStack(spacing: AutoDevViewTheme.compactSpacing) {
                        MetricRow(title: "并行槽位", value: viewModel.state.opsSnapshot.slotUsage)
                        MetricRow(title: "运行工作流", value: "\(viewModel.state.opsSnapshot.runningWorkflowCount)")
                        MetricRow(title: "排队中", value: "\(viewModel.state.opsSnapshot.queueDepth)")
                        MetricRow(title: "推进速度", value: viewModel.state.opsSnapshot.averageVelocity)
                        MetricRow(title: "成功率", value: "\(viewModel.state.opsSnapshot.successRate24h)%")
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }

                Divider()

                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    ForEach(Array(viewModel.state.progressNotices.prefix(2))) { notice in
                        HStack(alignment: .top, spacing: 8) {
                            Text(notice.time)
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                            Text(notice.title)
                                .font(.subheadline.weight(.medium))
                            Spacer()
                        }
                    }
                }
            }
        }
    }
}
