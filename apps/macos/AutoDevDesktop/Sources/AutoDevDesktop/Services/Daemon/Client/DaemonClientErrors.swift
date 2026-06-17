import Foundation

enum DaemonClientError: LocalizedError {
    case requestFailed(statusCode: Int, detail: String)
    case timedOut
    case emptyResponse
    case malformedResponse
    case daemonError(code: String, detail: String)

    var errorDescription: String? {
        switch self {
        case let .requestFailed(statusCode, detail):
            return "Daemon HTTP request failed: status=\(statusCode), \(detail)"
        case .timedOut:
            return "Daemon HTTP request timed out."
        case .emptyResponse:
            return "Daemon returned empty response."
        case .malformedResponse:
            return "Daemon response format is invalid."
        case let .daemonError(code, detail):
            return "Daemon error: \(code), \(detail)"
        }
    }
}
