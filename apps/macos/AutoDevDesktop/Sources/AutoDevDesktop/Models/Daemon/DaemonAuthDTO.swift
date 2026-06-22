import Foundation

struct DaemonLoginPayload: Decodable {
    let user: DaemonAuthenticatedUser
}

struct DaemonAuthenticatedUser: Decodable {
    let displayName: String
    let email: String
    let currentPlan: String
}
