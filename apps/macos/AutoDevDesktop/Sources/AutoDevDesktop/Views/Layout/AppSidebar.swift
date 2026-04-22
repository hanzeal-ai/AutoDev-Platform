import SwiftUI

struct AppSidebar: View {
    @ObservedObject var viewModel: ShellViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AutoDevViewTheme.pageSpacing) {
            HStack(spacing: 8) {
                Image(systemName: "shippingbox.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.accentColor)
                if !viewModel.state.isSidebarCollapsed {
                    Text("AI AutoDev")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                SidebarButton(
                    title: "总览",
                    isSelected: viewModel.state.route.isOverview,
                    icon: "rectangle.grid.2x2.fill",
                    isCollapsed: viewModel.state.isSidebarCollapsed,
                    action: { viewModel.openOverview() }
                )
                SidebarButton(
                    title: "项目库",
                    isSelected: viewModel.state.route.isProjectLibraryEntry,
                    icon: "tray.full.fill",
                    isCollapsed: viewModel.state.isSidebarCollapsed,
                    action: { viewModel.openProjectLibrary() }
                )
            }

            Spacer(minLength: 8)

            Menu {
                Button(viewModel.state.userProfile.displayName, action: {})
                    .disabled(true)
                Button(viewModel.state.userProfile.email, action: {})
                    .disabled(true)
                Divider()
                Button("升级版本", action: { viewModel.upgradeVersion() })
                Button("设置", action: { viewModel.openSettings() })
                Divider()
                Button("退出登录", role: .destructive, action: { viewModel.signOut() })
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.accentColor)
                    if !viewModel.state.isSidebarCollapsed {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(viewModel.state.userProfile.displayName)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .menuStyle(.borderlessButton)
            .help("用户中心")
        }
        .padding(10)
        .frame(width: viewModel.state.isSidebarCollapsed ? 58 : 146, alignment: .topLeading)
        .background(Color(nsColor: .underPageBackgroundColor))
    }
}

private struct SidebarButton: View {
    let title: String
    let isSelected: Bool
    let icon: String
    let isCollapsed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .frame(width: isCollapsed ? 24 : 16, alignment: .center)
                if !isCollapsed {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
            }
            .padding(.horizontal, isCollapsed ? 6 : 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: isCollapsed ? .center : .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .help(title)
    }
}
