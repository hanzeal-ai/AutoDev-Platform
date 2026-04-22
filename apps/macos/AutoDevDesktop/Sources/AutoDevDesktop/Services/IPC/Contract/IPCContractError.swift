import Foundation

enum IPCContractError: LocalizedError {
    case malformedEnvelope
    case malformedPayload
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .malformedEnvelope:
            return "IPC envelope format is invalid."
        case .malformedPayload:
            return "IPC payload format is invalid."
        case .decodeFailed:
            return "IPC payload decode failed."
        }
    }
}
