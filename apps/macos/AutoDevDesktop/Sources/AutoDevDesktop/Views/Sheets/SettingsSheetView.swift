import SwiftUI
import AppKit

struct SettingsSheetView: View {
    @ObservedObject var viewModel: ShellViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AutoDevViewTheme.pageSpacing) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("设置")
                        .font(.title2.weight(.semibold))
                    Text("界面与存储偏好")
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

            GroupBox("文件存储位置") {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
                    Picker(
                        "存储位置",
                        selection: Binding(
                            get: { viewModel.state.storageLocationMode },
                            set: { viewModel.setStorageLocationMode($0) }
                        )
                    ) {
                        ForEach(StorageLocationMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if viewModel.state.storageLocationMode == .local {
                        HStack(spacing: 8) {
                            Image(systemName: "folder")
                                .foregroundColor(.secondary)
                            Text(viewModel.state.localStoragePath)
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button("更改") {
                                chooseLocalStoragePath()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(.top, 2)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "cloud")
                                .foregroundColor(.secondary)
                            Text("云端存储将在后续版本接入")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(.vertical, 6)
            }

            GroupBox("阶段推进策略") {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
                    Picker(
                        "自动化模式",
                        selection: Binding(
                            get: { viewModel.state.stageAutomation.mode },
                            set: { viewModel.setStageAutomationMode($0) }
                        )
                    ) {
                        ForEach(StageAutomationMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch viewModel.state.stageAutomation.mode {
                    case .fullAuto:
                        Text("所有阶段将自动推进，AI 完成后自动进入下一阶段，无需人工确认。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    case .allManual:
                        Text("所有阶段都需要人工确认后才会推进，AI 不会自动触发。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    case .selective:
                        Text("选择需要人工确认的阶段，未选择的阶段将自动推进。")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(DeliveryLifecycleStage.allCases) { stage in
                                VStack(alignment: .leading, spacing: 0) {
                                    Toggle(
                                        isOn: Binding(
                                            get: { viewModel.state.stageAutomation.manualConfirmStages.contains(stage) },
                                            set: { _ in viewModel.toggleManualConfirmStage(stage) }
                                        )
                                    ) {
                                        HStack(spacing: 6) {
                                            Text(stage.rawValue)
                                                .font(.subheadline.weight(.medium))
                                            if stage.hasSubSteps {
                                                Text("\(stage.subSteps.count) 步")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 1)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                            .fill(Color.secondary.opacity(0.12))
                                                    )
                                            }
                                        }
                                    }
                                    .padding(.vertical, 3)

                                    if stage.hasSubSteps {
                                        VStack(alignment: .leading, spacing: 2) {
                                            ForEach(Array(stage.subSteps.enumerated()), id: \.offset) { index, step in
                                                HStack(spacing: 6) {
                                                    Circle()
                                                        .fill(Color.accentColor.opacity(0.5))
                                                        .frame(width: 5, height: 5)
                                                    Text(step.label)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                    if index < stage.subSteps.count - 1 {
                                                        Image(systemName: "arrow.right")
                                                            .font(.system(size: 8))
                                                            .foregroundColor(.secondary.opacity(0.5))
                                                    }
                                                }
                                            }
                                        }
                                        .padding(.leading, 24)
                                        .padding(.bottom, 4)
                                    }
                                }
                            }
                        }
                        .padding(.top, 4)

                        Toggle(
                            "子步骤之间也需人工确认推进",
                            isOn: Binding(
                                get: { viewModel.state.stageAutomation.manualSubSteps },
                                set: { viewModel.setManualSubSteps($0) }
                            )
                        )
                        .font(.subheadline)
                        .padding(.top, 4)
                    }
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
        .frame(minWidth: 520, minHeight: 400)
    }

    private func chooseLocalStoragePath() {
        let panel = NSOpenPanel()
        panel.title = "选择文件存储位置"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.setLocalStoragePath(url.path)
        }
    }
}
