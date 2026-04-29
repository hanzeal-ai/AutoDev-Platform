import Foundation

extension DaemonClient {
    func createCreationThread() async throws -> DaemonCommandResult {
        try await sendDecodedRequest(
            messageType: IPCContract.MessageType.createCreationThreadCommand,
            payload: [:],
            expectedResponse: IPCContract.MessageType.createCreationThreadSuccess
        ) { payload in
            try IPCPayloadDecoder.decode(DaemonCommandResult.self, from: payload)
        }
    }

    func renameCreationThread(threadID: String, title: String) async throws {
        _ = try await sendDecodedRequest(
            messageType: IPCContract.MessageType.renameCreationThreadCommand,
            payload: Self.renameCreationThreadPayload(threadID: threadID, title: title),
            expectedResponse: IPCContract.MessageType.renameCreationThreadSuccess
        ) { _ in true }
    }

    func archiveCreationThread(threadID: String) async throws {
        _ = try await sendDecodedRequest(
            messageType: IPCContract.MessageType.archiveCreationThreadCommand,
            payload: Self.threadIDPayload(threadID),
            expectedResponse: IPCContract.MessageType.archiveCreationThreadSuccess
        ) { _ in true }
    }

    func deleteCreationThread(threadID: String) async throws {
        _ = try await sendDecodedRequest(
            messageType: IPCContract.MessageType.deleteCreationThreadCommand,
            payload: Self.threadIDPayload(threadID),
            expectedResponse: IPCContract.MessageType.deleteCreationThreadSuccess
        ) { _ in true }
    }

    func addCreationMessage(threadID: String, content: String) async throws -> DaemonCommandResult {
        try await sendDecodedRequest(
            messageType: IPCContract.MessageType.addCreationMessageCommand,
            payload: Self.addCreationMessagePayload(threadID: threadID, content: content),
            expectedResponse: IPCContract.MessageType.addCreationMessageSuccess,
            timeoutSeconds: 60
        ) { payload in
            try IPCPayloadDecoder.decode(DaemonCommandResult.self, from: payload)
        }
    }

    func addCreationMaterials(threadID: String, paths: [String]) async throws {
        _ = try await sendDecodedRequest(
            messageType: IPCContract.MessageType.addCreationMaterialsCommand,
            payload: Self.addCreationMaterialsPayload(threadID: threadID, paths: paths),
            expectedResponse: IPCContract.MessageType.addCreationMaterialsSuccess
        ) { _ in true }
    }

    func confirmFeasibility(threadID: String) async throws -> DaemonCommandResult {
        try await sendDecodedRequest(
            messageType: IPCContract.MessageType.confirmFeasibilityCommand,
            payload: Self.threadIDPayload(threadID),
            expectedResponse: IPCContract.MessageType.confirmFeasibilitySuccess,
            timeoutSeconds: 60
        ) { payload in
            try IPCPayloadDecoder.decode(DaemonCommandResult.self, from: payload)
        }
    }

    func planDevelopment(projectID: String) async throws -> DaemonCommandResult {
        try await sendDecodedRequest(
            messageType: IPCContract.MessageType.planDevelopmentCommand,
            payload: Self.planDevelopmentPayload(projectID: projectID),
            expectedResponse: IPCContract.MessageType.planDevelopmentSuccess
        ) { payload in
            try IPCPayloadDecoder.decode(DaemonCommandResult.self, from: payload)
        }
    }

    func advanceProjectStage(projectID: String, action: String, autoTriggerAI: Bool) async throws -> DaemonCommandResult {
        try await sendDecodedRequest(
            messageType: IPCContract.MessageType.advanceProjectStageCommand,
            payload: Self.advanceProjectStagePayload(projectID: projectID, action: action, autoTriggerAI: autoTriggerAI),
            expectedResponse: IPCContract.MessageType.advanceProjectStageSuccess,
            timeoutSeconds: 60
        ) { payload in
            try IPCPayloadDecoder.decode(DaemonCommandResult.self, from: payload)
        }
    }

    func generateProjectStageAI(projectID: String, stage: String?, feedback: String?) async throws -> DaemonCommandResult {
        try await sendDecodedRequest(
            messageType: IPCContract.MessageType.generateProjectStageAICommand,
            payload: Self.generateProjectStageAIPayload(projectID: projectID, stage: stage, feedback: feedback),
            expectedResponse: IPCContract.MessageType.generateProjectStageAISuccess,
            timeoutSeconds: 60
        ) { payload in
            try IPCPayloadDecoder.decode(DaemonCommandResult.self, from: payload)
        }
    }

    func deleteProject(projectID: String) async throws {
        _ = try await sendDecodedRequest(
            messageType: IPCContract.MessageType.deleteProjectCommand,
            payload: Self.projectIDPayload(projectID),
            expectedResponse: IPCContract.MessageType.deleteProjectSuccess
        ) { _ in true }
    }

    // MARK: - Streaming Creation Message

    func addCreationMessageStreaming(
        threadID: String,
        content: String
    ) -> CreationStreamingHandle {
        let cancelHandle = CancellableSocket()
        let handle = CreationStreamingHandle(cancelHandle: cancelHandle)

        handle.stream = AsyncStream { continuation in
            continuation.onTermination = { @Sendable _ in
                cancelHandle.cancel()
            }

            DispatchQueue.global(qos: .userInitiated).async { [self] in
                do {
                    let line = try Self.encodeRequestLine(
                        messageType: IPCContract.MessageType.addCreationMessageStreamCommand,
                        payload: Self.addCreationMessagePayload(threadID: threadID, content: content)
                    )
                    try DaemonUnixSocketTransport.exchangeStreaming(
                        line: line,
                        socketPath: socketPath,
                        cancelHandle: cancelHandle,
                        timeoutSeconds: 120
                    ) { responseData in
                        // Check cancellation on each line
                        guard !cancelHandle.isCancelled else { return false }

                        guard let envelope = try? IPCResponseEnvelope.decode(from: responseData) else {
                            return true // skip unparseable lines
                        }

                        switch envelope.messageType {
                        case IPCContract.MessageType.creationMessageDelta:
                            if let delta = envelope.payload["delta"] as? String {
                                continuation.yield(.delta(delta))
                            }
                            return true

                        case IPCContract.MessageType.creationMessageDone:
                            do {
                                let result = try IPCPayloadDecoder.decode(DaemonCommandResult.self, from: envelope.payload)
                                continuation.yield(.done(result))
                            } catch {
                                continuation.yield(.error(error.localizedDescription))
                            }
                            continuation.finish()
                            return false

                        case IPCContract.MessageType.creationMessageError:
                            let errorMsg = envelope.payload["error"] as? String ?? "Unknown error"
                            continuation.yield(.error(errorMsg))
                            continuation.finish()
                            return false

                        case IPCContract.MessageType.error:
                            let detail = envelope.payload["detail"] as? String ?? "Request failed"
                            continuation.yield(.error(detail))
                            continuation.finish()
                            return false

                        default:
                            return true
                        }
                    }
                    // If we got here without finishing (e.g. cancelled), finish now
                    continuation.finish()
                } catch {
                    if !cancelHandle.isCancelled {
                        continuation.yield(.error(error.localizedDescription))
                    }
                    continuation.finish()
                }
            }
        }

        return handle
    }
}

// MARK: - Stream Event & Handle

enum CreationStreamEvent: Sendable {
    case delta(String)
    case done(DaemonCommandResult)
    case error(String)
}

/// Bundles an AsyncStream with a cancellation handle for direct socket shutdown.
final class CreationStreamingHandle: @unchecked Sendable {
    var stream: AsyncStream<CreationStreamEvent> = AsyncStream { $0.finish() }
    private let cancelHandle: CancellableSocket

    init(cancelHandle: CancellableSocket) {
        self.cancelHandle = cancelHandle
    }

    /// Immediately shuts down the underlying socket, stopping all I/O.
    func cancel() {
        cancelHandle.cancel()
    }
}
