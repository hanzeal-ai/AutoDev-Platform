import SwiftUI

extension ProjectDetailPage {
    func uiWorkspace(detail: DeliveryExecutionDetail?) -> some View {
        let activeSubStep = detail?.activeSubStep ?? viewModel.state.selectedSubStep ?? "page_map"

        return VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
            if activeSubStep == "interaction" {
                uiInteractionContent(detail: detail)
            } else {
                uiPageMapContent(detail: detail)
            }
        }
    }

    /// 页面地图 — page inventory + navigation structure
    @ViewBuilder
    private func uiPageMapContent(detail: DeliveryExecutionDetail?) -> some View {
        let lines = detail?.inputContexts ?? []
        let map = AutoDevTextSupport.value(for: "页面地图", in: lines)
        let steps = detail?.stepProgress ?? []
        let artifacts = detail?.outputArtifacts ?? []
        let downloads = stageDownloads(in: [.stageSnapshot, .rawInput, .auditArchive])

        stageModule("页面清单", when: !steps.isEmpty) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(steps) { step in
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                        Text(step.title)
                            .font(.subheadline)
                            .lineLimit(2)
                            .foregroundColor(.primary)
                    }
                }
            }
        }

        stageModule("导航结构", when: map != nil) {
            if let map {
                Text(map)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }

        stageModule("阶段产物", when: !artifacts.isEmpty || !downloads.isEmpty) {
            VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                if !artifacts.isEmpty {
                    StageArtifactListView(viewModel: viewModel, items: artifacts)
                }
                if !downloads.isEmpty {
                    StageDownloadListView(viewModel: viewModel, items: downloads)
                }
            }
        }
    }

    /// 交互稿 — component definitions + interaction flows + design specs
    @ViewBuilder
    private func uiInteractionContent(detail: DeliveryExecutionDetail?) -> some View {
        let lines = detail?.inputContexts ?? []
        let components = AutoDevTextSupport.value(for: "关键组件", in: lines)
        let flow = AutoDevTextSupport.value(for: "核心交互流", in: lines)
        let vision = AutoDevTextSupport.value(for: "视觉方向", in: lines)
        let confirmPoint = AutoDevTextSupport.value(for: "待确认设计点", in: lines)
        let artifacts = detail?.outputArtifacts ?? []
        let prototypeDownloads = stageDownloads(in: [.stageSnapshot])

        stageModule("交互稿下载", when: !prototypeDownloads.isEmpty) {
            StageDownloadListView(viewModel: viewModel, items: prototypeDownloads)
        }

        stageModule("组件定义", when: components != nil) {
            if let components {
                Text(components)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }

        stageModule("交互流程", when: flow != nil) {
            if let flow {
                Text(flow)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }

        stageModule("设计规范", when: vision != nil || confirmPoint != nil) {
            VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                if let vision {
                    KeyValueRow(key: "视觉方向", value: vision)
                }
                if let confirmPoint {
                    KeyValueRow(key: "待确认设计点", value: confirmPoint)
                }
            }
        }

        stageModule("阶段产物", when: !artifacts.isEmpty) {
            StageArtifactListView(viewModel: viewModel, items: artifacts)
        }
    }
}
