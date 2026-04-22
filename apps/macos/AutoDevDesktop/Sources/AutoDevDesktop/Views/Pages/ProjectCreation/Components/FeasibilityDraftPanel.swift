import SwiftUI

struct FeasibilityDraftPanel: View {
    let draft: FeasibilityReportDraft?
    let selectedThreadID: UUID?
    let selectedLifecycleStage: DeliveryLifecycleStage
    let isConfirmingFeasibility: Bool
    let onTogglePanel: () -> Void
    let onInsertReference: (String) -> Void
    let onConfirmFeasibility: (UUID) -> Void

    var body: some View {
        DashboardCard(title: "可行性报告草稿") {
            VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
                HStack {
                    Text("结构化草稿")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button(action: onTogglePanel) {
                        Image(systemName: "sidebar.right")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                HStack {
                    LifecycleBadge(stage: selectedLifecycleStage)
                    Spacer()
                    Button(action: {
                        guard let selectedThreadID = selectedThreadID else { return }
                        onConfirmFeasibility(selectedThreadID)
                    }) {
                        if isConfirmingFeasibility {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("确认中...")
                            }
                        } else {
                            Text("确认立项")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        selectedLifecycleStage != .feasibility ||
                            selectedThreadID == nil ||
                            isConfirmingFeasibility
                    )
                }

                if let draft = draft {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
                            ReportSectionView(
                                title: "项目名称",
                                text: draft.projectName,
                                referenceKey: "项目名称",
                                onInsertReference: onInsertReference
                            )
                            ReportSectionView(
                                title: "问题定义",
                                text: draft.problemDefinition,
                                referenceKey: "问题定义",
                                onInsertReference: onInsertReference
                            )
                            ReportSectionView(
                                title: "目标用户",
                                text: draft.targetUsers,
                                referenceKey: "目标用户",
                                onInsertReference: onInsertReference
                            )
                            ReportListSectionView(
                                title: "核心能力",
                                items: draft.coreCapabilities,
                                referenceKey: "核心能力",
                                onInsertReference: onInsertReference
                            )
                            ReportListSectionView(
                                title: "风险与约束",
                                items: draft.risksAndConstraints,
                                referenceKey: "风险与约束",
                                onInsertReference: onInsertReference
                            )
                            ReportListSectionView(
                                title: "初步交付建议",
                                items: draft.initialDeliveryPlan,
                                referenceKey: "初步交付建议",
                                onInsertReference: onInsertReference
                            )
                            ReportSectionView(
                                title: "可行性结论",
                                text: draft.feasibilityConclusion,
                                referenceKey: "可行性结论",
                                onInsertReference: onInsertReference
                            )
                        }
                        .padding(.vertical, 2)
                    }
                } else {
                    Text("请选择线程查看报告草稿。")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
