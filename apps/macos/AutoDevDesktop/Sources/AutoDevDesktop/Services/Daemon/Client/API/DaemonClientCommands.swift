import Foundation

extension DaemonClient {
    func login(username: String, password: String) async throws -> DaemonAuthenticatedUser {
        try await sendDecodedRequest(
            messageType: IPCContract.MessageType.loginCommand,
            payload: Self.loginPayload(username: username, password: password),
            expectedResponse: IPCContract.MessageType.loginSuccess
        ) { payload in
            try IPCPayloadDecoder.decode(DaemonLoginPayload.self, from: payload).user
        }
    }

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
            timeoutSeconds: 900
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

    func runProjectWorkflow(projectID: String, feedback: String?, action: String?) async throws -> DaemonCommandResult {
        try await sendDecodedRequest(
            messageType: IPCContract.MessageType.runProjectWorkflowCommand,
            payload: Self.runProjectWorkflowPayload(projectID: projectID, feedback: feedback, action: action),
            expectedResponse: IPCContract.MessageType.runProjectWorkflowSuccess,
            timeoutSeconds: 900
        ) { payload in
            try IPCPayloadDecoder.decode(DaemonCommandResult.self, from: payload)
        }
    }

    func runProjectWorkflowStreaming(projectID: String, feedback: String?, action: String?, mode: String) -> WorkflowStreamingHandle {
        let handle = WorkflowStreamingHandle()

        handle.stream = AsyncStream { continuation in
            continuation.onTermination = { @Sendable _ in
                handle.cancel()
            }

            let task = Task { [self] in
                do {
                    let body = try Self.encodeRequestBody(
                        messageType: IPCContract.MessageType.runProjectWorkflowStreamCommand,
                        payload: Self.runProjectWorkflowStreamPayload(
                            projectID: projectID,
                            feedback: feedback,
                            action: action,
                            mode: mode
                        )
                    )
                    try await DaemonHTTPTransport.exchangeStreaming(
                        body: body,
                        baseURL: apiBaseURL,
                        timeoutSeconds: 900
                    ) { responseData in
                        guard !Task.isCancelled else { return false }
                        if let rawLine = String(data: responseData, encoding: .utf8) {
                            continuation.yield(.raw(rawLine))
                        }
                        guard let envelope = try? IPCResponseEnvelope.decode(from: responseData) else {
                            return true
                        }

                        switch envelope.messageType {
                        case IPCContract.MessageType.projectWorkflowUpdate:
                            if let status = try? Self.decodeWorkflowStatus(from: envelope.payload) {
                                let event = try? Self.decodeWorkflowEvent(from: envelope.payload)
                                continuation.yield(.update(status, event))
                            }
                            return true

                        case IPCContract.MessageType.projectWorkflowDone:
                            let status = try? Self.decodeWorkflowStatus(from: envelope.payload)
                            let event = try? Self.decodeWorkflowEvent(from: envelope.payload)
                            continuation.yield(.done(status, event))
                            continuation.finish()
                            return false

                        case IPCContract.MessageType.projectWorkflowError:
                            let detail = envelope.payload["detail"] as? String ?? "Workflow stream failed"
                            continuation.yield(.error(detail))
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
                    continuation.finish()
                } catch {
                    if !Task.isCancelled {
                        continuation.yield(.error(error.localizedDescription))
                    }
                    continuation.finish()
                }
            }
            handle.attach(task: task)
        }

        return handle
    }

    func startProjectWorkflow(projectID: String, feedback: String?, action: String?) async throws -> DaemonCommandResult {
        try await sendDecodedRequest(
            messageType: IPCContract.MessageType.startProjectWorkflowCommand,
            payload: Self.runProjectWorkflowPayload(projectID: projectID, feedback: feedback, action: action),
            expectedResponse: IPCContract.MessageType.startProjectWorkflowSuccess,
            timeoutSeconds: 900
        ) { payload in
            try IPCPayloadDecoder.decode(DaemonCommandResult.self, from: payload)
        }
    }

    func resumeProjectWorkflow(projectID: String, feedback: String?, action: String?) async throws -> DaemonCommandResult {
        try await sendDecodedRequest(
            messageType: IPCContract.MessageType.resumeProjectWorkflowCommand,
            payload: Self.runProjectWorkflowPayload(projectID: projectID, feedback: feedback, action: action),
            expectedResponse: IPCContract.MessageType.resumeProjectWorkflowSuccess,
            timeoutSeconds: 900
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
        let handle = CreationStreamingHandle()

        handle.stream = AsyncStream { continuation in
            continuation.onTermination = { @Sendable _ in
                handle.cancel()
            }

            let task = Task { [self] in
                do {
                    let body = try Self.encodeRequestBody(
                        messageType: IPCContract.MessageType.addCreationMessageStreamCommand,
                        payload: Self.addCreationMessagePayload(threadID: threadID, content: content)
                    )
                    try await DaemonHTTPTransport.exchangeStreaming(
                        body: body,
                        baseURL: apiBaseURL,
                        timeoutSeconds: 900
                    ) { responseData in
                        // Check cancellation on each line
                        guard !Task.isCancelled else { return false }

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
                    if !Task.isCancelled {
                        continuation.yield(.error(error.localizedDescription))
                    }
                    continuation.finish()
                }
            }
            handle.attach(task: task)
        }

        return handle
    }

    private static func decodeWorkflowStatus(from payload: [String: Any]) throws -> DaemonProjectWorkflowStatus {
        if let status = payload["status"] as? [String: Any] {
            return try IPCPayloadDecoder.decode(DaemonProjectWorkflowStatus.self, from: status)
        }
        return try IPCPayloadDecoder.decode(DaemonProjectWorkflowStatus.self, from: payload)
    }

    private static func decodeWorkflowEvent(from payload: [String: Any]) throws -> DaemonWorkflowEvent {
        guard let event = payload["event"] as? [String: Any] else {
            throw DaemonClientError.malformedResponse
        }
        return try IPCPayloadDecoder.decode(DaemonWorkflowEvent.self, from: event)
    }
}

// MARK: - Stream Event & Handle

enum WorkflowStreamEvent: Sendable {
    case raw(String)
    case update(DaemonProjectWorkflowStatus, DaemonWorkflowEvent?)
    case done(DaemonProjectWorkflowStatus?, DaemonWorkflowEvent?)
    case error(String)
}

enum CreationStreamEvent: Sendable {
    case delta(String)
    case done(DaemonCommandResult)
    case error(String)
}

final class WorkflowStreamingHandle: @unchecked Sendable {
    var stream: AsyncStream<WorkflowStreamEvent> = AsyncStream { $0.finish() }
    private let lock = NSLock()
    private var task: Task<Void, Never>?

    func attach(task: Task<Void, Never>) {
        lock.lock()
        defer { lock.unlock() }
        self.task = task
    }

    func cancel() {
        lock.lock()
        let task = self.task
        self.task = nil
        lock.unlock()
        task?.cancel()
    }
}

/// Bundles an AsyncStream with a cancellation handle for the HTTP stream task.
final class CreationStreamingHandle: @unchecked Sendable {
    var stream: AsyncStream<CreationStreamEvent> = AsyncStream { $0.finish() }
    private let lock = NSLock()
    private var task: Task<Void, Never>?

    func attach(task: Task<Void, Never>) {
        lock.lock()
        defer { lock.unlock() }
        self.task = task
    }

    func cancel() {
        lock.lock()
        let task = self.task
        self.task = nil
        lock.unlock()
        task?.cancel()
    }
}
