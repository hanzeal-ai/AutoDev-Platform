import Foundation

enum StructuredLogWriter {
    static func write(component: String, level: String, message: String) {
        guard let baseURL = logBaseURL() else {
            return
        }

        let componentURL = baseURL
            .appendingPathComponent("logs")
            .appendingPathComponent(component)
        let combinedURL = componentURL.appendingPathComponent("combined.log")
        let levelURL = componentURL.appendingPathComponent("\(level.lowercased()).log")
        let line = "[\(Date())] [\(level)] \(message)\n"

        guard let data = line.data(using: .utf8) else {
            return
        }

        write(data: data, to: combinedURL)
        write(data: data, to: levelURL)
    }

    private static func write(data: Data, to url: URL) {
        let directory = url.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: url.path) {
                if let handle = try? FileHandle(forWritingTo: url) {
                    _ = try? handle.seekToEnd()
                    try? handle.write(contentsOf: data)
                    try? handle.close()
                }
            } else {
                FileManager.default.createFile(atPath: url.path, contents: data)
            }
        } catch {
            return
        }
    }

    private static func logBaseURL() -> URL? {
        let sourceURL = URL(fileURLWithPath: #filePath)
        var directory = sourceURL.deletingLastPathComponent()
        while directory.path != "/" {
            if FileManager.default.fileExists(
                atPath: directory.appendingPathComponent("logs").path
            ) {
                return directory
            }
            directory.deleteLastPathComponent()
        }
        return nil
    }
}
