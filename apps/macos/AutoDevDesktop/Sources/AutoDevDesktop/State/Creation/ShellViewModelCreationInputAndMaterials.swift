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
            creationStreamTask = Task { [weak self] in
                guard let self else { return }
                do {
                    try await sendCreationInputToDaemon(
                        threadID: threadID,
                        rawInput: trimmed,
                        allowRetry: true
                    )
                } catch {
                    if !Task.isCancelled {
                        if let selectedThreadID = state.selectedEffectiveCreationThreadID {
                            let errorMessage = localCreationMessage(
                                role: .ai,
                                content: "系统提示：发送失败（\(error.localizedDescription)）。请稍后重试。"
                            )
                            appendTransientCreationMessage(errorMessage, threadID: selectedThreadID)
                        }
                        state.apply(operationError: error, context: "发送消息")
                    }
                }
                // Only clean up if this task wasn't cancelled
                // (cancelled tasks are cleaned up by cancelCreationMessage)
                if !Task.isCancelled {
                    isSendingCreationMessage = false
                    creationStreamTask = nil
                    creationStreamHandle = nil
                }
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

        // Create an empty AI message that will accumulate streaming deltas
        let streamingAIMessage = CreationConversationMessage(
            id: UUID(),
            role: .ai,
            content: "",
            timestamp: "刚刚",
            isLoading: true
        )
        appendTransientCreationMessage(streamingAIMessage, threadID: threadID)

        var accumulatedContent = ""
        var shouldPreserveStreamingMessage = false
        do {
            let streamingHandle = daemonClient.addCreationMessageStreaming(
                threadID: threadID.uuidString,
                content: rawInput
            )
            creationStreamHandle = streamingHandle

            for await event in streamingHandle.stream {
                // Check cooperative cancellation on each iteration
                if Task.isCancelled { break }

                switch event {
                case .delta(let delta):
                    accumulatedContent += delta
                    updateTransientCreationMessage(
                        threadID: threadID,
                        messageID: streamingAIMessage.id,
                        content: accumulatedContent,
                        isLoading: true
                    )

                case .done(let result):
                    // Clear ALL transient messages (includes leftover from cancelled sends)
                    clearTransientCreationMessages(threadID: threadID)
                    applyCreationMessageResult(
                        threadID: threadID,
                        assistantMessage: result.assistantMessage,
                        reportDraft: result.reportDraft
                    )
                    try await refreshCreationThreads()
                    state.selectCreationThread(threadID)
                    return

                case .error(let errorMsg):
                    // Update the streaming message to show the error
                    shouldPreserveStreamingMessage = true
                    updateTransientCreationMessage(
                        threadID: threadID,
                        messageID: streamingAIMessage.id,
                        content: "系统提示：\(errorMsg)",
                        isLoading: false
                    )
                    removeTransientCreationMessages(threadID: threadID, messageIDs: [transientUserMessage.id])
                    throw DaemonClientError.daemonError(code: "stream_error", detail: errorMsg)
                }
            }

            // Stream ended — either naturally or by cancellation
            if Task.isCancelled {
                // Cancelled: keep accumulated content visible as a stopped message
                if !accumulatedContent.isEmpty {
                    updateTransientCreationMessage(
                        threadID: threadID,
                        messageID: streamingAIMessage.id,
                        content: accumulatedContent,
                        isLoading: false
                    )
                }
                return
            }

            // Stream ended without done event — treat accumulated content as final
            if !accumulatedContent.isEmpty {
                clearTransientCreationMessages(threadID: threadID)
                applyCreationMessageResult(
                    threadID: threadID,
                    assistantMessage: accumulatedContent,
                    reportDraft: nil
                )
                try await refreshCreationThreads()
                state.selectCreationThread(threadID)
            }
        } catch {
            // Clean up transient messages on failure
            if !shouldPreserveStreamingMessage && accumulatedContent.isEmpty {
                removeTransientCreationMessages(threadID: threadID, messageIDs: [
                    transientUserMessage.id,
                    streamingAIMessage.id
                ])
            } else {
                removeTransientCreationMessages(threadID: threadID, messageIDs: [transientUserMessage.id])
                if !shouldPreserveStreamingMessage {
                    updateTransientCreationMessage(
                        threadID: threadID,
                        messageID: streamingAIMessage.id,
                        content: accumulatedContent,
                        isLoading: false
                    )
                }
            }

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

    // MARK: - Retry & Cancel

    func retryLastCreationMessage(threadID: UUID) {
        // Find the last user message for this thread
        guard let thread = state.creationThreads.first(where: { $0.id == threadID }) else { return }
        guard let lastUserMessage = thread.messages.last(where: { $0.role == .user }) else { return }
        sendCreationInput(threadID: threadID, lastUserMessage.content)
    }

    func cancelCreationMessage() {
        guard isSendingCreationMessage else { return }

        // 1. Cancel the HTTP stream task immediately
        creationStreamHandle?.cancel()
        creationStreamHandle = nil

        // 2. Cancel the Task — sets cooperative cancellation flag
        creationStreamTask?.cancel()
        creationStreamTask = nil

        isSendingCreationMessage = false

        // Keep accumulated streaming content visible, remove loading indicators
        if let threadID = state.selectedEffectiveCreationThreadID {
            if let messages = transientCreationMessagesByThread[threadID] {
                for message in messages where message.isLoading {
                    if message.content.isEmpty {
                        removeTransientCreationMessage(messageID: message.id, threadID: threadID)
                    } else {
                        updateTransientCreationMessage(
                            threadID: threadID,
                            messageID: message.id,
                            content: message.content,
                            isLoading: false
                        )
                    }
                }
            }
        }
    }
}
