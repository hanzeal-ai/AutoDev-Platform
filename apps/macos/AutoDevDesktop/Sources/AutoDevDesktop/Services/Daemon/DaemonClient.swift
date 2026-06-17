import Foundation

final class DaemonClient: @unchecked Sendable {
    let apiBaseURL: URL

    init(apiBaseURL: URL = DaemonClient.defaultAPIBaseURL()) {
        self.apiBaseURL = apiBaseURL
    }

    static func defaultAPIBaseURL() -> URL {
        if let configured = ProcessInfo.processInfo.environment["AUTODEV_API_BASE_URL"],
           let url = URL(string: configured),
           !configured.isEmpty {
            return url
        }
        return URL(string: "http://127.0.0.1:7373")!
    }
}
