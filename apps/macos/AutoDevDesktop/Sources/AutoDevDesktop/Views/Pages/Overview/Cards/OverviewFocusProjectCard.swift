import SwiftUI

struct OverviewFocusProjectCard: View {
    @ObservedObject var viewModel: ShellViewModel

    var body: some View {
        DashboardCard(title: "焦点项目") {
            VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
                if let focus = viewModel.state.focusProject {
                    HStack {
                        HStack(spacing: 8) {
                            Text(focus.title)
                                .font(.headline.weight(.semibold))
                            LifecycleBadge(stage: focus.lifecycleStage)
                        }
                        Spacer()
                        Text(focus.status.rawValue)
                            .font(.caption.weight(.medium))
                            .foregroundColor(focus.status.color)
                    }

                    HStack {
                        Text(focus.currentPhase)
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int((focus.progress * 100).rounded()))%")
                            .font(.headline.monospaced())
                    }
                    MeterBar(value: focus.progress)
                    FocusRow(label: "当前目标", value: focus.currentGoal)
                    FocusRow(label: "下一动作", value: focus.nextAction)
                    HStack {
                        Text(focus.updateTime)
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(focus.blockReason == nil ? "畅通" : "阻塞")
                            .font(.caption.weight(.medium))
                            .foregroundColor(focus.blockReason == nil ? .green : .red)
                    }
                } else {
                    Text("暂无")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
