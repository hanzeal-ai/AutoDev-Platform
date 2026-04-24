import Foundation

extension DaemonClient {
    func getHealth() async throws -> DaemonHealth {
        try await sendDecodedRequest(
            messageType: IPCContract.MessageType.getHealthQuery,
            payload: [:],
            expectedResponse: IPCContract.MessageType.getHealthSuccess
        ) { payload in
            try IPCPayloadDecoder.decode(DaemonHealth.self, from: payload)
        }
    }

    func getOverview() async throws -> DaemonOverviewPayload {
        try await sendDecodedRequest(
            messageType: IPCContract.MessageType.getOverviewQuery,
            payload: [:],
            expectedResponse: IPCContract.MessageType.getOverviewSuccess
        ) { payload in
            try IPCPayloadDecoder.decode(DaemonOverviewPayload.self, from: payload)
        }
    }

    func listProjects() async throws -> [DaemonProject] {
        try await sendDecodedRequest(
            messageType: IPCContract.MessageType.listProjectsQuery,
            payload: [:],
            expectedResponse: IPCContract.MessageType.listProjectsSuccess
        ) { payload in
            try IPCPayloadDecoder.decode(DaemonProjectListPayload.self, from: payload).projects
        }
    }

    func listCreationThreads() async throws -> [DaemonCreationThread] {
        try await sendDecodedRequest(
            messageType: IPCContract.MessageType.listCreationThreadsQuery,
            payload: [:],
            expectedResponse: IPCContract.MessageType.listCreationThreadsSuccess
        ) { payload in
            try IPCPayloadDecoder.decode(DaemonThreadListPayload.self, from: payload).threads
        }
    }

    func getProjectStageDetail(projectID: String, stage: String?, subStep: String? = nil) async throws -> DaemonProjectStageDetail {
        try await sendDecodedRequest(
            messageType: IPCContract.MessageType.getProjectStageDetailQuery,
            payload: Self.projectStageDetailPayload(projectID: projectID, stage: stage, subStep: subStep),
            expectedResponse: IPCContract.MessageType.getProjectStageDetailSuccess
        ) { payload in
            try IPCPayloadDecoder.decode(DaemonProjectStageDetailPayload.self, from: payload).detail
        }
    }
}
