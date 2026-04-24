import SwiftUI

extension ProjectDetailPage {
    func prdWorkspace(detail: DeliveryExecutionDetail?) -> some View {
        let contexts = detail?.inputContexts ?? []
        let steps = detail?.stepProgress ?? []
        let criteria = detail?.eventFlow ?? []
        let milestones = detail?.secondaryActions ?? []
        let downloads = stageDownloads(in: [.stageSnapshot, .rawInput, .auditArchive])
        let artifacts = detail?.outputArtifacts ?? []
        let risks = detail?.riskItems ?? []

        return VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
            stageModule("概述", when: !(detail?.objective.isEmpty ?? true)) {
                Text(detail?.objective ?? "")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            stageModule("目标与非目标", when: !contexts.isEmpty) {
                StageBulletsView(items: contexts)
            }

            stageModule("功能清单", when: !steps.isEmpty) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(steps) { step in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(prdStepColor(step.status))
                                .frame(width: 8, height: 8)
                            Text(step.title)
                                .font(.subheadline)
                                .lineLimit(2)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }

            stageModule("验收标准", when: !criteria.isEmpty) {
                StageBulletsView(items: criteria)
            }

            stageModule("里程碑", when: !milestones.isEmpty) {
                StageBulletsView(items: milestones)
            }

            stageModule("风险项", when: !risks.isEmpty) {
                StageBulletsView(items: risks)
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
    }

    private func prdStepColor(_ status: ProjectStatus) -> Color {
        switch status {
        case .completed: return .green
        case .running: return .accentColor
        case .blocked, .failed: return .red
        default: return .secondary
        }
    }
}
