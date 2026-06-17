import Foundation

extension DaemonClient {
    static func projectStageDetailPayload(projectID: String, stage: String?, subStep: String? = nil) -> [String: Any] {
        var payload: [String: Any] = ["project_id": projectID]
        if let stage = stage {
            payload["stage"] = stage
        }
        if let subStep = subStep {
            payload["sub_step"] = subStep
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

    static func projectIDPayload(_ projectID: String) -> [String: Any] {
        ["project_id": projectID]
    }

    static func runProjectWorkflowPayload(projectID: String, feedback: String?) -> [String: Any] {
        var payload: [String: Any] = ["project_id": projectID]
        if let feedback, !feedback.isEmpty {
            payload["feedback"] = feedback
        }
        return payload
    }

    static func encodeRequestBody(messageType: String, payload: [String: Any]) throws -> Data {
        let request = IPCRequestEnvelope.make(messageType: messageType, payload: payload)
        return try JSONSerialization.data(withJSONObject: request.jsonObject(), options: [])
    }

    static func encodeRequestLine(messageType: String, payload: [String: Any]) throws -> Data {
        let body = try encodeRequestBody(messageType: messageType, payload: payload)
        var out = body
        out.append(contentsOf: [0x0A])
        return out
    }
}
