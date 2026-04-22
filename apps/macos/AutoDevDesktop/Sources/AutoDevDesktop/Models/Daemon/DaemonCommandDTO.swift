import Foundation

struct DaemonCommandResult: Decodable {
    let threadId: String?
    let projectId: String?
    let addedCount: Int?
    let assistantMessage: String?
    let reportDraft: DaemonFeasibilityReport?
}
