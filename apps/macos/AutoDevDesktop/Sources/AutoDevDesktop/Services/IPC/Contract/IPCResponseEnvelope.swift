import Foundation

struct IPCResponseEnvelope {
    let messageType: String
    let payload: [String: Any]

    static func decode(from data: Data) throws -> IPCResponseEnvelope {
        guard
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let messageType = object["message_type"] as? String,
            let payload = object["payload"] as? [String: Any]
        else {
            throw IPCContractError.malformedEnvelope
        }

        return IPCResponseEnvelope(messageType: messageType, payload: payload)
    }
}

struct IPCErrorPayload {
    let code: String
    let detail: String

    init(jsonObject: [String: Any]) throws {
        guard
            let code = jsonObject["code"] as? String,
            let detail = jsonObject["detail"] as? String
        else {
            throw IPCContractError.malformedPayload
        }
        self.code = code
        self.detail = detail
    }
}
