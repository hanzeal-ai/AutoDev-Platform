import Foundation

enum DaemonHTTPTransport {
    static func exchange(
        body: Data,
        baseURL: URL,
        timeoutSeconds: TimeInterval = 5,
        session: URLSession = .shared
    ) async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent("rpc"))
        request.httpMethod = "POST"
        request.timeoutInterval = timeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        guard !data.isEmpty else {
            throw DaemonClientError.emptyResponse
        }
        return data
    }

    static func exchangeStreaming(
        body: Data,
        baseURL: URL,
        timeoutSeconds: TimeInterval = 120,
        session: URLSession = .shared,
        onLine: @escaping (Data) throws -> Bool
    ) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("rpc"))
        request.httpMethod = "POST"
        request.timeoutInterval = timeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/x-ndjson", forHTTPHeaderField: "Accept")
        request.httpBody = body

        let (bytes, response) = try await session.bytes(for: request)
        try validate(response: response, data: Data())
        for try await line in bytes.lines {
            if Task.isCancelled {
                return
            }
            guard !line.isEmpty else {
                continue
            }
            let shouldContinue = try onLine(Data(line.utf8))
            if !shouldContinue {
                return
            }
        }
    }

    private static func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw DaemonClientError.malformedResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let detail = String(data: data, encoding: .utf8) ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw DaemonClientError.requestFailed(statusCode: http.statusCode, detail: detail)
        }
    }
}
