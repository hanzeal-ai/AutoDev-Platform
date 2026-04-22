import Foundation

enum DaemonClientError: LocalizedError {
    case socketCreateFailed
    case socketPathTooLong
    case connectFailed(code: Int32)
    case writeFailed(code: Int32)
    case readFailed(code: Int32)
    case connectionClosed
    case timedOut
    case emptyResponse
    case malformedResponse
    case daemonError(code: String, detail: String)

    var errorDescription: String? {
        switch self {
        case .socketCreateFailed:
            return "Cannot create IPC socket."
        case .socketPathTooLong:
            return "Socket path is too long for Unix domain socket."
        case let .connectFailed(code):
            return "Cannot connect to daemon. errno=\(code)."
        case let .writeFailed(code):
            return "Cannot send request to daemon. errno=\(code)."
        case let .readFailed(code):
            return "Cannot read daemon response. errno=\(code)."
        case .connectionClosed:
            return "Daemon closed the IPC connection."
        case .timedOut:
            return "Daemon IPC request timed out."
        case .emptyResponse:
            return "Daemon returned empty response."
        case .malformedResponse:
            return "Daemon response format is invalid."
        case let .daemonError(code, detail):
            return "Daemon error: \(code), \(detail)"
        }
    }
}
