import SwiftUI

struct CreationConversationPanel: View {
    let selectedThreadTitle: String?
    let selectedThreadStage: DeliveryLifecycleStage
    let selectedMaterials: [CreationMaterialItem]
    let selectedMessages: [CreationConversationMessage]
    let selectedThreadID: UUID?
    let isSendingMessage: Bool
    let creationInputDraft: Binding<String>
    let creationInputInsertionRequest: Binding<CreationInputInsertionRequest?>
    let onImportMaterials: () -> Void
    let onRemoveMaterial: (UUID) -> Void
    let onSendMessage: (UUID, String) -> Void

    var body: some View {
        DashboardCard(title: "AI 立项对话") {
            VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
                HStack {
                    if let selectedThreadTitle = selectedThreadTitle {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(selectedThreadTitle)
                                    .font(.headline.weight(.semibold))
                                LifecycleBadge(stage: selectedThreadStage)
                            }
                        }
                    } else {
                        Text("请选择一个线程开始")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }

                CreationMaterialsPanel(
                    materials: selectedMaterials,
                    onImportMaterials: onImportMaterials,
                    onRemoveMaterial: onRemoveMaterial
                )

                Divider()

                ScrollView {
                    LazyVStack(spacing: AutoDevViewTheme.compactSpacing) {
                        if selectedMessages.isEmpty {
                            Text("暂无会话内容。")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            ForEach(selectedMessages) { message in
                                CreationMessageRowView(message: message)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: .infinity)

                Divider()

                CreationComposer(
                    threadID: selectedThreadID,
                    isSending: isSendingMessage,
                    draft: creationInputDraft,
                    insertionRequest: creationInputInsertionRequest,
                    onSend: { threadID, value in
                        onSendMessage(threadID, value)
                    }
                )
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}
