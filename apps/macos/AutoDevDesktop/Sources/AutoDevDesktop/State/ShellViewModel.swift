import SwiftUI

@MainActor
final class ShellViewModel: ObservableObject {
    @Published var state: ShellViewState
    @Published var isChecking: Bool = false
    @Published var isConfirmingFeasibility: Bool = false
    @Published var isPlanningDevelopment: Bool = false
    @Published var isGeneratingStageAI: Bool = false
    @Published var isSendingCreationMessage: Bool = false
    @Published private(set) var transientCreationMessagesByThread: [UUID: [CreationConversationMessage]] = [:]
    var creationStreamTask: Task<Void, Never>?
    var creationStreamHandle: CreationStreamingHandle?

    let daemonClient: DaemonQuerying
    let dataMode: ShellDataMode
    let autoHealthCheck: Bool
    var hasLoaded = false
    var detailRefreshTask: Task<Void, Never>?
    var stageAIRefreshTask: Task<Void, Never>?
    var autoAdvanceTask: Task<Void, Never>?
    var healthCheckTask: Task<Void, Never>?
    var autoAdvanceDepth: Int = 0
    static let maxAutoAdvanceDepth = 3

    init(
        daemonClient: DaemonQuerying = DaemonClient(),
        dataMode: ShellDataMode = .sampleOnly,
        autoHealthCheck: Bool? = nil,
        initialState: ShellViewState? = nil
    ) {
        self.daemonClient = daemonClient
        self.dataMode = dataMode
        self.autoHealthCheck = autoHealthCheck ?? (
            dataMode == .liveDaemon &&
                !ProcessInfo.processInfo.environment.keys.contains("XCODE_RUNNING_FOR_PREVIEWS")
        )
        self.state = initialState ?? .initial(apiBaseURL: daemonClient.apiBaseURL)
    }

    func displayedCreationMessages(
        threadID: UUID?,
        persistedMessages: [CreationConversationMessage]
    ) -> [CreationConversationMessage] {
        guard let threadID = threadID else {
            return persistedMessages
        }
        let transient = transientCreationMessagesByThread[threadID] ?? []
        return persistedMessages + transient
    }

    func appendTransientCreationMessage(_ message: CreationConversationMessage, threadID: UUID) {
        var messages = transientCreationMessagesByThread[threadID] ?? []
        messages.append(message)
        transientCreationMessagesByThread[threadID] = messages
    }

    func removeTransientCreationMessages(threadID: UUID, messageIDs: [UUID]) {
        guard var messages = transientCreationMessagesByThread[threadID] else {
            return
        }
        messages.removeAll { messageIDs.contains($0.id) }
        if messages.isEmpty {
            transientCreationMessagesByThread.removeValue(forKey: threadID)
        } else {
            transientCreationMessagesByThread[threadID] = messages
        }
    }

    func clearTransientCreationMessages(threadID: UUID) {
        transientCreationMessagesByThread.removeValue(forKey: threadID)
    }

    func removeTransientCreationMessage(messageID: UUID, threadID: UUID) {
        guard var messages = transientCreationMessagesByThread[threadID] else {
            return
        }
        messages.removeAll { $0.id == messageID }
        if messages.isEmpty {
            transientCreationMessagesByThread.removeValue(forKey: threadID)
        } else {
            transientCreationMessagesByThread[threadID] = messages
        }
    }

    func updateTransientCreationMessage(
        threadID: UUID,
        messageID: UUID,
        content: String,
        isLoading: Bool
    ) {
        guard var messages = transientCreationMessagesByThread[threadID] else { return }
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else { return }
        let existing = messages[index]
        messages[index] = CreationConversationMessage(
            id: existing.id,
            role: existing.role,
            content: content,
            timestamp: existing.timestamp,
            isLoading: isLoading
        )
        transientCreationMessagesByThread[threadID] = messages
    }
}
