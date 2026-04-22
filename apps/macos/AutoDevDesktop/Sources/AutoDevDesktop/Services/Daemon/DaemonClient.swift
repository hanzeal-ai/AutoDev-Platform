import Foundation

final class DaemonClient: @unchecked Sendable {
    let socketPath: String

    init(socketPath: String = DaemonClient.defaultSocketPath()) {
        self.socketPath = socketPath
    }

    static func defaultSocketPath() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return home + "/Library/Application Support/com.sanmws.autodev/ipc/daemon.sock"
    }
}
