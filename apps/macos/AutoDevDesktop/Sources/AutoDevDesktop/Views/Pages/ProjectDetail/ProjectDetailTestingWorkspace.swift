import SwiftUI

extension ProjectDetailPage {
    func testingWorkspace(detail: DeliveryExecutionDetail?) -> some View {
        let activeSubStep = detail?.activeSubStep ?? viewModel.state.selectedSubStep ?? "test_plan"

        return VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
            if activeSubStep == "quality_report" {
                testingQualityReportContent(detail: detail)
            } else {
                testingPlanContent(detail: detail)
            }
        }
    }

    /// 测试计划 — strategy, test cases, coverage
    @ViewBuilder
    private func testingPlanContent(detail: DeliveryExecutionDetail?) -> some View {
        let lines = detail?.inputContexts ?? []
        let testScope = AutoDevTextSupport.value(for: "测试范围", in: lines)
        let steps = detail?.stepProgress ?? []
        let artifacts = detail?.outputArtifacts ?? []
        let downloads = stageDownloads(in: [.stageSnapshot, .auditArchive])

        stageModule("策略概览", when: testScope != nil || !(detail?.objective.isEmpty ?? true)) {
            VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                if let scope = testScope {
                    MetricPill(title: "测试范围", value: scope)
                }
                if let objective = detail?.objective, !objective.isEmpty {
                    Text(objective)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }

        stageModule("测试用例", when: !steps.isEmpty) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(steps) { step in
                    HStack(spacing: 8) {
                        Image(systemName: testCaseIcon(step.status))
                            .font(.caption)
                            .foregroundColor(testCaseColor(step.status))
                        Text(step.title)
                            .font(.subheadline)
                            .lineLimit(2)
                            .foregroundColor(.primary)
                    }
                }
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

    /// 质量报告 — quality score, gate, defects
    @ViewBuilder
    private func testingQualityReportContent(detail: DeliveryExecutionDetail?) -> some View {
        let lines = detail?.inputContexts ?? []
        let passRate = AutoDevTextSupport.value(for: "通过率", in: lines)
        let regression = AutoDevTextSupport.value(for: "回归状态", in: lines)
        let blockers = AutoDevTextSupport.compactItems([
            AutoDevTextSupport.value(for: "失败项", in: lines),
            AutoDevTextSupport.value(for: "阻塞项", in: lines),
        ])
        let risks = detail?.riskItems ?? []
        let artifacts = detail?.outputArtifacts ?? []
        let downloads = stageDownloads(in: [.stageSnapshot, .auditArchive])

        stageModule("质量指标", when: passRate != nil || regression != nil) {
            HStack(spacing: 12) {
                if let passRate {
                    MetricPill(title: "通过率", value: passRate, valueColor: .green)
                }
                if let regression {
                    MetricPill(title: "回归状态", value: regression)
                }
            }
        }

        stageModule("缺陷清单", when: !blockers.isEmpty || detail?.blockerReason != nil) {
            VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
                StageBulletsView(items: blockers)
                if let blockerReason = detail?.blockerReason {
                    KeyValueRow(key: "阻塞原因", value: blockerReason)
                }
            }
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

    private func testCaseIcon(_ status: ProjectStatus) -> String {
        switch status {
        case .completed: return "checkmark.circle.fill"
        case .running: return "play.circle.fill"
        case .blocked, .failed: return "xmark.circle.fill"
        default: return "circle"
        }
    }

    private func testCaseColor(_ status: ProjectStatus) -> Color {
        switch status {
        case .completed: return .green
        case .running: return .accentColor
        case .blocked, .failed: return .red
        default: return .secondary
        }
    }
}
