import Foundation

struct UserProfileSummary {
    var displayName: String
    var email: String
    var currentPlan: String

    init(displayName: String, email: String, currentPlan: String) {
        self.displayName = displayName
        self.email = email
        self.currentPlan = currentPlan
    }

    init(daemonUser: DaemonAuthenticatedUser) {
        self.displayName = daemonUser.displayName
        self.email = daemonUser.email
        self.currentPlan = daemonUser.currentPlan
    }
}
