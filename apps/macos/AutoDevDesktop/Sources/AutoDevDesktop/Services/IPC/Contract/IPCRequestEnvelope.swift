import Foundation

struct IPCRequestEnvelope {
    let messageID: String
    let correlationID: String
    let messageType: String
    let schemaVersion: UInt32
    let timestamp: Int
    let payload: [String: Any]

    static func make(messageType: String, payload: [String: Any] = [:]) -> IPCRequestEnvelope {
        IPCRequestEnvelope(
            messageID: UUID().uuidString,
            correlationID: UUID().uuidString,
            messageType: messageType,
            schemaVersion: IPCContract.schemaVersion,
            timestamp: Int(Date().timeIntervalSince1970 * 1000),
            payload: payload
        )
    }

    static func getHealth() -> IPCRequestEnvelope {
        make(messageType: IPCContract.MessageType.getHealthQuery)
    }

    func jsonObject() -> [String: Any] {
        [
            "message_id": messageID,
            "correlation_id": correlationID,
            "message_type": messageType,
            "schema_version": schemaVersion,
            "timestamp": timestamp,
            "payload": payload,
        ]
    }
}
