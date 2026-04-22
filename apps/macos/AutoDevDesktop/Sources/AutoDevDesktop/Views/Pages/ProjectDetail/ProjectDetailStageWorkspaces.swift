import SwiftUI

extension ProjectDetailPage {
    @ViewBuilder
    func detailStageWorkspace(project: DeliveryProjectItem, detail: DeliveryExecutionDetail?) -> some View {
        switch viewModel.state.activeDetailStage {
        case .feasibility:
            feasibilityWorkspace(project: project, detail: detail)
        case .prd:
            prdWorkspace(detail: detail)
        case .ui:
            uiWorkspace(detail: detail)
        case .development:
            developmentWorkspace(detail: detail)
        case .testing:
            testingWorkspace(detail: detail)
        case .release:
            releaseWorkspace(detail: detail)
        case .maintenance:
            maintenanceWorkspace(detail: detail)
        }
    }

    func stageDownloads(in categories: [StageDownloadCategory]) -> [StageDownloadItem] {
        viewModel.state.selectedStageDownloads.filter { categories.contains($0.category) }
    }

    func stageWorkspaceSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            content()
        }
    }

    @ViewBuilder
    func stageModule<Content: View>(
        _ title: String,
        when isVisible: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if isVisible {
            stageWorkspaceSection(title) {
                content()
            }
        }
    }
}
