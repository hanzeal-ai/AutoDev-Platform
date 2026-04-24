import SwiftUI

struct AppHeader: View {
    @ObservedObject var viewModel: ShellViewModel

    var body: some View {
        HStack(alignment: .center, spacing: AutoDevViewTheme.pageSpacing) {
            Button(action: { viewModel.toggleSidebar() }) {
                Image(systemName: viewModel.state.isSidebarCollapsed ? "sidebar.right" : "sidebar.left")
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(viewModel.state.isSidebarCollapsed ? "展开侧边栏" : "收起侧边栏")

            if viewModel.state.route.isProjectDetail || viewModel.state.route.isProjectCreation {
                Button(action: navigateBack) {
                    Label("返回", systemImage: "chevron.left")
                }
                .buttonStyle(.bordered)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(viewModel.state.route.title)
                    .font(.title3.weight(.semibold))
                Text(headerSubtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if viewModel.state.route.isOverview {
                Text(viewModel.state.operationsSummaryLine)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if !viewModel.state.route.isProjectDetail {
                HeaderStatusLabel(status: viewModel.state.daemonStatus)

                Button(action: { Task { await viewModel.runHealthCheck() } }) {
                    if viewModel.isChecking {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("刷新状态")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isChecking)
                .accessibilityLabel("刷新系统状态")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var headerSubtitle: String {
        switch viewModel.state.route {
        case .projectDetail:
            return viewModel.state.selectedProject?.title ?? "阶段详情"
        case .projectCreation:
            return "立项 · \(viewModel.state.deepseekStatusLine)"
        case .projectLibrary:
            return "项目目录"
        case .overview:
            return viewModel.state.operationsSummaryLine
        }
    }

    private func navigateBack() {
        if viewModel.state.route.isProjectDetail {
            viewModel.backFromProjectDetail()
        } else {
            viewModel.openProjectLibrary()
        }
    }
}

private struct HeaderStatusLabel: View {
    let status: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: AutoDevViewTheme.daemonStatusIcon(status))
                .foregroundColor(AutoDevViewTheme.daemonStatusColor(status))
                .font(.caption)
            Text("系统 \(status)")
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("系统状态：\(status)")
    }
}
