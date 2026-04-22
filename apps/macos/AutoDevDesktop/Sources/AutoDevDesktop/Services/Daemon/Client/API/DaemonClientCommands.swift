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
            expectedResponse: IPCContract.MessageType.addCreationMessageSuccess
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
            expectedResponse: IPCContract.MessageType.confirmFeasibilitySuccess
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
}
