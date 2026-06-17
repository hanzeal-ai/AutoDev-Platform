import Foundation

extension DaemonClient {
    func sendDecodedRequest<T: Sendable>(
        messageType: String,
        payload: [String: Any],
        expectedResponse: String,
        timeoutSeconds: TimeInterval = 5,
        decode: @escaping @Sendable ([String: Any]) throws -> T
    ) async throws -> T {
        let responsePayload = try await sendRequest(
            messageType: messageType,
            payload: payload,
            expectedResponse: expectedResponse,
            timeoutSeconds: timeoutSeconds
        )
        return try decode(responsePayload)
    }

    func sendRequest(
        messageType: String,
        payload: [String: Any],
        expectedResponse: String,
        timeoutSeconds: TimeInterval = 5
    ) async throws -> [String: Any] {
        let body = try Self.encodeRequestBody(messageType: messageType, payload: payload)
        let responseBody = try await DaemonHTTPTransport.exchange(
            body: body,
            baseURL: apiBaseURL,
            timeoutSeconds: timeoutSeconds
        )
        return try decodeResponsePayload(responseBody, expectedResponse: expectedResponse)
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
