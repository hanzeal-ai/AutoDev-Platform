import SwiftUI

struct ProjectCreationPage: View {
    @ObservedObject var viewModel: ShellViewModel

    var body: some View {
        let state = viewModel.state
        let selectedThread = state.selectedCreationThread
        let selectedThreadID = state.selectedEffectiveCreationThreadID
        let selectedThreadStage = selectedThread?.lifecycleStage ?? .feasibility
        let selectedMaterials = selectedThread?.materials ?? []
        let selectedMessages = viewModel.displayedCreationMessages(
            threadID: selectedThreadID,
            persistedMessages: state.selectedCreationMessages
        )
        let creationInputDraftBinding = Binding(
            get: { viewModel.state.creationInputDraft },
            set: { viewModel.updateCreationInputDraft($0) }
        )
        let creationInputInsertionRequestBinding = Binding(
            get: { viewModel.state.creationInputInsertionRequest },
            set: { newValue in
                if newValue == nil {
                    viewModel.state.clearCreationInputInsertionRequest()
                } else {
                    viewModel.state.creationInputInsertionRequest = newValue
                }
            }
        )
        let isConfirmingFeasibility = viewModel.isConfirmingFeasibility
        let isSendingCreationMessage = viewModel.isSendingCreationMessage

        return VStack(spacing: AutoDevViewTheme.pageSpacing) {
            DashboardCard(title: "生命周期轨道") {
                LifecycleTrack(current: .feasibility, compact: false)
            }

            HStack(alignment: .top, spacing: AutoDevViewTheme.pageSpacing) {
                if state.isCreationThreadPanelCollapsed {
                    CollapsedCreationRail(
                        title: "线程",
                        systemImage: "sidebar.left",
                        action: { viewModel.toggleCreationThreadPanel() }
                    )
                    .frame(width: 44)
                } else {
                    CreationThreadPanel(
                        threads: state.orderedCreationThreads,
                        selectedThreadID: selectedThreadID,
                        onTogglePanel: { viewModel.toggleCreationThreadPanel() },
                        onCreateThread: { viewModel.createNewCreationThread() },
                        onSelectThread: { threadID in viewModel.selectCreationThread(threadID) },
                        onBeginRenameThread: { threadID in viewModel.beginRenameCreationThread(threadID) },
                        onArchiveThread: { threadID in viewModel.archiveCreationThread(threadID) },
                        onDeleteThread: { threadID in viewModel.deleteCreationThread(threadID) }
                    )
                    .frame(width: 248)
                    .frame(maxHeight: .infinity, alignment: .top)
                }

                    CreationConversationPanel(
                        selectedThreadTitle: selectedThread?.title,
                        selectedThreadStage: selectedThreadStage,
                        selectedMaterials: selectedMaterials,
                        selectedMessages: selectedMessages,
                        selectedThreadID: selectedThreadID,
                        isSendingMessage: isSendingCreationMessage,
                        creationInputDraft: creationInputDraftBinding,
                        creationInputInsertionRequest: creationInputInsertionRequestBinding,
                        onImportMaterials: { viewModel.setMaterialImporterPresented(true) },
                        onRemoveMaterial: { materialID in viewModel.removeCreationMaterial(materialID) },
                        onSendMessage: { threadID, input in viewModel.sendCreationInput(threadID: threadID, input) }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if state.isReportPanelCollapsed {
                    CollapsedCreationRail(
                        title: "草稿",
                        systemImage: "sidebar.right",
                        action: { viewModel.toggleReportPanel() }
                    )
                    .frame(width: 44)
                } else {
                    FeasibilityDraftPanel(
                        draft: selectedThread?.reportDraft,
                        selectedThreadID: selectedThreadID,
                        selectedLifecycleStage: selectedThreadStage,
                        isConfirmingFeasibility: isConfirmingFeasibility,
                        onTogglePanel: { viewModel.toggleReportPanel() },
                        onInsertReference: { reference in viewModel.appendCreationInputReference(reference) },
                        onConfirmFeasibility: { threadID in viewModel.confirmFeasibilityAndEnterPRD(threadID: threadID) }
                    )
                    .frame(width: 372)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
