import Foundation

extension DaemonClient {
    func sendDecodedRequest<T>(
        messageType: String,
        payload: [String: Any],
        expectedResponse: String,
        timeoutSeconds: TimeInterval = 5,
        decode: @escaping ([String: Any]) throws -> T
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let responsePayload = try self.sendRequestSync(
                        messageType: messageType,
                        payload: payload,
                        expectedResponse: expectedResponse,
                        timeoutSeconds: timeoutSeconds
                    )
                    let value = try decode(responsePayload)
                    continuation.resume(returning: value)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func sendRequestSync(
        messageType: String,
        payload: [String: Any],
        expectedResponse: String,
        timeoutSeconds: TimeInterval = 5
    ) throws -> [String: Any] {
        let line = try Self.encodeRequestLine(messageType: messageType, payload: payload)
        let responseLine = try DaemonUnixSocketTransport.exchange(
            line: line,
            socketPath: socketPath,
            timeoutSeconds: timeoutSeconds
        )
        return try decodeResponsePayload(responseLine, expectedResponse: expectedResponse)
    }

    func decodeResponsePayload(_ line: Data, expectedResponse: String) throws -> [String: Any] {
        let envelope = try IPCResponseEnvelope.decode(from: line)
        if envelope.messageType == IPCContract.MessageType.error {
            let payload = try IPCErrorPayload(jsonObject: envelope.payload)
            throw DaemonClientError.daemonError(code: payload.code, detail: payload.detail)
        }
        guard envelope.messageType == expectedResponse else {
            throw DaemonClientError.malformedResponse
        }
        return envelope.payload
    }
}
