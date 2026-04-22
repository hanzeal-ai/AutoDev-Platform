import Foundation

extension ShellViewModel {
    func selectCreationThread(_ threadID: UUID) {
        state.selectCreationThread(threadID)
    }

    func createNewCreationThread() {
        switch dataMode {
        case .sampleOnly:
            state.createNewCreationThread()
        case .liveDaemon:
            Task {
                do {
                    let result = try await daemonClient.createCreationThread()
                    try await refreshCreationThreads()
                    if let threadID = result.threadId.flatMap(UUID.init(uuidString:)) {
                        state.openProjectCreation()
                        state.selectCreationThread(threadID)
                    }
                } catch {
                    state.apply(operationError: error, context: "创建线程")
                }
            }
        }
    }

    func archiveCreationThread(_ threadID: UUID) {
        switch dataMode {
        case .sampleOnly:
            state.archiveCreationThread(threadID)
        case .liveDaemon:
            Task {
                do {
                    try await daemonClient.archiveCreationThread(threadID: threadID.uuidString)
                    try await refreshCreationThreads()
                } catch {
                    state.apply(operationError: error, context: "归档线程")
                }
            }
        }
    }

    func deleteCreationThread(_ threadID: UUID) {
        switch dataMode {
        case .sampleOnly:
            state.deleteCreationThread(threadID)
        case .liveDaemon:
            Task {
                do {
                    try await daemonClient.deleteCreationThread(threadID: threadID.uuidString)
                    try await refreshCreationThreads()
                } catch {
                    state.apply(operationError: error, context: "删除线程")
                }
            }
        }
    }

    func beginRenameCreationThread(_ threadID: UUID) {
        state.beginRenameCreationThread(threadID)
    }

    func updateRenameThreadDraft(_ title: String) {
        state.updateRenameThreadDraft(title)
    }

    func applyRenameCreationThread() {
        let draft = state.renameThreadDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !draft.isEmpty else { return }
        switch dataMode {
        case .sampleOnly:
            state.applyRenameCreationThread()
        case .liveDaemon:
            guard let threadID = state.renameThreadTargetID else {
                return
            }
            Task {
                do {
                    try await daemonClient.renameCreationThread(threadID: threadID.uuidString, title: draft)
                    state.dismissRenameCreationThread()
                    try await refreshCreationThreads()
                } catch {
                    state.apply(operationError: error, context: "重命名线程")
                }
            }
        }
    }

    func dismissRenameCreationThread() {
        state.dismissRenameCreationThread()
    }
}
