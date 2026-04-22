import SwiftUI

extension ProjectDetailPage {
    func uiWorkspace(detail: DeliveryExecutionDetail?) -> some View {
        let lines = detail?.inputContexts ?? []
        let map = AutoDevTextSupport.value(for: "页面地图", in: lines)
        let components = AutoDevTextSupport.value(for: "关键组件", in: lines)
        let flow = AutoDevTextSupport.value(for: "核心交互流", in: lines)
        let vision = AutoDevTextSupport.value(for: "视觉方向", in: lines)
        let confirmPoint = AutoDevTextSupport.value(for: "待确认设计点", in: lines)
        let downloads = stageDownloads(in: [.stageSnapshot])

        return VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
            StageAIExecutionProgressView(
                viewModel: viewModel,
                stage: .ui,
                detail: detail,
                downloads: downloads
            )

            stageModule("UI 方案摘要", when: detail?.objective.isEmpty == false) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    if let objective = detail?.objective, !objective.isEmpty {
                        KeyValueRow(key: "目标", value: objective)
                    }
                }
            }

            stageModule("页面结构", when: map != nil || components != nil) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    if let map {
                        KeyValueRow(key: "页面地图", value: map)
                    }
                    if let components {
                        KeyValueRow(key: "关键组件", value: components)
                    }
                }
            }

            stageModule("关键交互", when: flow != nil || vision != nil) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    if let flow {
                        KeyValueRow(key: "核心交互流", value: flow)
                    }
                    if let vision {
                        KeyValueRow(key: "视觉方向", value: vision)
                    }
                }
            }

            stageModule("待确认设计点", when: confirmPoint != nil || !downloads.isEmpty) {
                VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                    if let confirmPoint {
                        Text(confirmPoint)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if !downloads.isEmpty {
                        StageDownloadListView(viewModel: viewModel, items: downloads)
                    }
                }
            }
        }
    }
}
