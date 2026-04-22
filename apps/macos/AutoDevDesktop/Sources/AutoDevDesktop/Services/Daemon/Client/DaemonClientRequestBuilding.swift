import Foundation

extension DaemonClient {
    static func projectStageDetailPayload(projectID: String, stage: String?) -> [String: Any] {
        var payload: [String: Any] = ["project_id": projectID]
        if let stage = stage {
            payload["stage"] = stage
        }
        return payload
    }

    static func renameCreationThreadPayload(threadID: String, title: String) -> [String: Any] {
        [
            "thread_id": threadID,
            "title": title,
        ]
    }

    static func addCreationMessagePayload(threadID: String, content: String) -> [String: Any] {
        [
            "thread_id": threadID,
            "content": content,
        ]
    }

    static func addCreationMaterialsPayload(threadID: String, paths: [String]) -> [String: Any] {
        [
            "thread_id": threadID,
            "materials": paths.map { ["path": $0] },
        ]
    }

    static func threadIDPayload(_ threadID: String) -> [String: Any] {
        ["thread_id": threadID]
    }

    static func planDevelopmentPayload(projectID: String) -> [String: Any] {
        ["project_id": projectID]
    }

    static func advanceProjectStagePayload(projectID: String, action: String) -> [String: Any] {
        [
            "project_id": projectID,
            "action": action,
        ]
    }

    static func generateProjectStageAIPayload(projectID: String, stage: String?) -> [String: Any] {
        var payload: [String: Any] = ["project_id": projectID]
        if let stage {
            payload["stage"] = stage
        }
        return payload
    }

    static func encodeRequestLine(messageType: String, payload: [String: Any]) throws -> Data {
        let request = IPCRequestEnvelope.make(messageType: messageType, payload: payload)
        let body = try JSONSerialization.data(withJSONObject: request.jsonObject(), options: [])
        var out = body
        out.append(contentsOf: [0x0A])
        return out
    }
}
