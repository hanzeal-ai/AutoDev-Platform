import Foundation

enum DaemonBootstrapper {
    static func shouldLaunchLocalServices(apiBaseURL: URL = DaemonClient.defaultAPIBaseURL()) -> Bool {
        guard let host = apiBaseURL.host?.lowercased() else {
            return false
        }
        return host == "127.0.0.1" || host == "localhost" || host == "::1"
    }

    static func launchIfNeeded() -> Bool {
        guard let scriptURL = locateScript("scripts/dev-daemon.sh") else {
            StructuredLogWriter.write(component: "autodev-app", level: "ERROR", message: "missing daemon script")
            return false
        }

        return runScript(scriptURL, label: "daemon")
    }

    static func launchAIWorkerIfNeeded() -> Bool {
        guard let scriptURL = locateScript("scripts/dev-ai-worker.sh") else {
            StructuredLogWriter.write(component: "autodev-app", level: "WARN", message: "missing ai-worker script, skipping")
            return false
        }

        return runScript(scriptURL, label: "ai-worker")
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

    // MARK: - Private

    private static func runScript(_ scriptURL: URL, label: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptURL.path]
        process.currentDirectoryURL = scriptURL.deletingLastPathComponent().deletingLastPathComponent()

        do {
            try process.run()
            StructuredLogWriter.write(component: "autodev-app", level: "INFO", message: "launched \(label) script: \(scriptURL.path)")
            return true
        } catch {
            StructuredLogWriter.write(component: "autodev-app", level: "ERROR", message: "\(label) launch failed: \(error.localizedDescription)")
            return false
        }
    }

    private static func locateScript(_ relativePath: String) -> URL? {
        if let override = ProcessInfo.processInfo.environment["AUTODEV_ROOT_DIR"] {
            let candidate = URL(fileURLWithPath: override).appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        var directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        while directory.path != "/" {
            let candidate = directory.appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            directory.deleteLastPathComponent()
        }

        directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while directory.path != "/" {
            let candidate = directory.appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            directory.deleteLastPathComponent()
        }

        return nil
    }
}
