import Foundation

enum DaemonBootstrapper {
    static func launchIfNeeded() -> Bool {
        guard let scriptURL = daemonScriptURL() else {
            StructuredLogWriter.write(component: "autodev-app", level: "ERROR", message: "missing daemon script")
            return false
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptURL.path]
        process.currentDirectoryURL = scriptURL.deletingLastPathComponent().deletingLastPathComponent()

        do {
            try process.run()
            StructuredLogWriter.write(component: "autodev-app", level: "INFO", message: "launched daemon script: \(scriptURL.path)")
            return true
        } catch {
            StructuredLogWriter.write(component: "autodev-app", level: "ERROR", message: "launch failed: \(error.localizedDescription)")
            return false
        }
    }

    static func waitForHealth(using daemonClient: DaemonQuerying, attempts: Int = 10, delayNanoseconds: UInt64 = 300_000_000) async -> DaemonHealth? {
        for attempt in 0..<attempts {
            do {
                return try await daemonClient.getHealth()
            } catch {
                if attempt + 1 == attempts {
                    return nil
                }
                try? await Task.sleep(nanoseconds: delayNanoseconds)
            }
        }
        return nil
    }

    private static func daemonScriptURL() -> URL? {
        if let override = ProcessInfo.processInfo.environment["AUTODEV_ROOT_DIR"] {
            let candidate = URL(fileURLWithPath: override).appendingPathComponent("scripts/dev-daemon.sh")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        var directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        while directory.path != "/" {
            let candidate = directory.appendingPathComponent("scripts/dev-daemon.sh")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            directory.deleteLastPathComponent()
        }

        return nil
    }
}
