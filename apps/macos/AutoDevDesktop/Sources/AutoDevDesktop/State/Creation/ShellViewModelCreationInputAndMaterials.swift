import Foundation

extension ShellViewModel {
    func updateCreationInputDraft(_ input: String) {
        state.updateCreationInputDraft(input)
    }

    func appendCreationInputReference(_ reference: String) {
        state.requestCreationInputInsertion(reference)
    }

    func addCreationMaterials(urls: [URL]) {
        switch dataMode {
        case .sampleOnly:
            state.addCreationMaterials(urls: urls)
        case .liveDaemon:
            Task { [weak self] in
                guard let self else { return }
                do {
                    let threadID = try await resolveActiveCreationThreadIDAfterRefresh()
                    try await daemonClient.addCreationMaterials(
                        threadID: threadID.uuidString,
                        paths: urls.map(\.path)
                    )
                    try await refreshCreationThreads()
                    state.selectCreationThread(threadID)
                } catch {
                    state.apply(operationError: error, context: "导入资料")
                }
            }
        }
    }

    func handleCreationMaterialImportFailure(_ error: Error) {
        state.apply(operationError: error, context: "导入资料")
    }

    func removeCreationMaterial(_ materialID: UUID) {
        state.removeCreationMaterial(materialID)
    }

    func sendCreationInput() {
        sendCreationInput(state.creationInputDraft)
    }

    func sendCreationInput(_ rawInput: String) {
        guard let threadID = state.selectedEffectiveCreationThreadID else {
            state.apply(operationError: CreationThreadSelectionError.invalidSelectedThread, context: "发送消息")
            return
        }
        sendCreationInput(threadID: threadID, rawInput)
    }

    func sendCreationInput(threadID: UUID, _ rawInput: String) {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        switch dataMode {
        case .sampleOnly:
            state.updateCreationInputDraft(trimmed)
            state.sendCreationInput()
        case .liveDaemon:
            guard !isSendingCreationMessage else { return }
            isSendingCreationMessage = true
            Task { [weak self] in
                guard let self else { return }
                do {
                    try await sendCreationInputToDaemon(
                        threadID: threadID,
                        rawInput: trimmed,
                        allowRetry: true
                    )
                } catch {
                    if let selectedThreadID = state.selectedEffectiveCreationThreadID {
                        let errorMessage = localCreationMessage(
                            role: .ai,
                            content: "系统提示：发送失败（\(error.localizedDescription)）。请稍后重试。"
                        )
                        appendTransientCreationMessage(errorMessage, threadID: selectedThreadID)
                    }
                    state.apply(operationError: error, context: "发送消息")
                }
                isSendingCreationMessage = false
            }
        }
    }

    private func sendCreationInputToDaemon(
        threadID: UUID,
        rawInput: String,
        allowRetry: Bool
    ) async throws {
        let transientUserMessage = localCreationMessage(role: .user, content: rawInput)
        appendTransientCreationMessage(transientUserMessage, threadID: threadID)
        let transientLoadingMessage = localLoadingCreationMessage(threadID: threadID)
        appendTransientCreationMessage(transientLoadingMessage, threadID: threadID)

        defer {
            removeTransientCreationMessages(threadID: threadID, messageIDs: [
                transientUserMessage.id,
                transientLoadingMessage.id
            ])
        }

        do {
            let result = try await daemonClient.addCreationMessage(
                threadID: threadID.uuidString,
                content: rawInput
            )
            applyCreationMessageResult(
                threadID: threadID,
                assistantMessage: result.assistantMessage,
                reportDraft: result.reportDraft
            )
            try await refreshCreationThreads()
            state.selectCreationThread(threadID)
        } catch {
            if allowRetry, isStaleCreationThreadError(error) {
                StructuredLogWriter.write(
                    component: "autodev-app",
                    level: "WARN",
                    message: "retry send after stale thread: \(error.localizedDescription)"
                )
                let resolvedThreadID = try await resolveActiveCreationThreadIDAfterRefresh(expectedThreadID: threadID)
                try await sendCreationInputToDaemon(
                    threadID: resolvedThreadID,
                    rawInput: rawInput,
                    allowRetry: false
                )
                return
            }
            throw error
        }
    }

    private func isStaleCreationThreadError(_ error: Error) -> Bool {
        guard case let DaemonClientError.daemonError(code, detail) = error, code == "request_failed" else {
            return false
        }
        return detail.contains("当前线程不存在或已失效") || detail.contains("当前线程已归档或失效")
    }

    private func localCreationMessage(
        role: CreationMessageRole,
        content: String
    ) -> CreationConversationMessage {
        CreationConversationMessage(
            id: UUID(),
            role: role,
            content: content,
            timestamp: "刚刚",
            isLoading: false
        )
    }

    private func localLoadingCreationMessage(threadID _: UUID) -> CreationConversationMessage {
        CreationConversationMessage(
            id: UUID(),
            role: .ai,
            content: "AI 正在生成回复...",
            timestamp: "刚刚",
            isLoading: true
        )
    }
}
