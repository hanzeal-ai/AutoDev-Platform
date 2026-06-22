import Foundation

struct DaemonProjectWorkflowStatusPayload: Decodable {
    let workflow: DaemonProjectWorkflowStatus
}

struct DaemonProjectWorkflowEventsPayload: Decodable {
    let workflowEvents: DaemonProjectWorkflowEvents
}

struct DaemonProjectWorkflowStatus: Decodable {
    let workflowId: String
    let threadId: String
    let projectId: String
    let projectName: String
    let currentPhase: String
    let currentStep: String
    let status: String
    let awaitingUserInput: Bool
    let error: String?
    let phases: [String: DaemonWorkflowPhase]
    let artifacts: [DaemonWorkflowArtifact]
}

struct DaemonWorkflowPhase: Decodable {
    let status: String
    let artifactId: String?
    let name: String
    let kind: String
    let fileName: String?
    let filePath: String?
}

struct DaemonWorkflowArtifact: Decodable {
    let artifactId: String
    let stage: String
    let name: String
    let kind: String
    let status: String
    let fileName: String?
    let filePath: String?
}

struct DaemonProjectWorkflowEvents: Decodable {
    let workflowId: String
    let threadId: String
    let projectId: String
    let projectName: String
    let currentPhase: String
    let currentStep: String
    let status: String
    let awaitingUserInput: Bool
    let error: String?
    let events: [DaemonWorkflowEvent]
}

struct DaemonWorkflowEvent: Decodable {
    let id: String
    let sequence: Int
    let type: String
    let stage: String
    let title: String
    let detail: String
    let status: String
    let artifactId: String?
}
