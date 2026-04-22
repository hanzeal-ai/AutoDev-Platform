import SwiftUI

struct SettingsSheetView: View {
    @ObservedObject var viewModel: ShellViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AutoDevViewTheme.pageSpacing) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("设置")
                        .font(.title2.weight(.semibold))
                    Text("界面偏好")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("关闭") {
                    viewModel.setSettingsPresented(false)
                }
                .buttonStyle(.bordered)
            }

            GroupBox("外观模式") {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
                    Picker(
                        "外观",
                        selection: Binding(
                            get: { viewModel.state.appearanceMode },
                            set: { viewModel.setAppearanceMode($0) }
                        )
                    ) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("当前模式：\(viewModel.state.appearanceMode.rawValue)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 6)
            }

            GroupBox("其他设置（占位）") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("通知偏好、快捷键与运行策略将在后续版本接入。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 6)
            }

            Spacer(minLength: 0)
        }
        .padding(22)
        .frame(minWidth: 520, minHeight: 320)
    }
}
