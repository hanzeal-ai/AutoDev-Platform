import Foundation
import XCTest
@testable import AutoDevDesktop

final class DaemonHTTPTransportTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testExchangePostsEnvelopeToRPCPath() async throws {
        let session = makeMockSession { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString, "https://api.autodev.test/rpc")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            let requestBody = try XCTUnwrap(Self.bodyData(from: request))
            XCTAssertEqual(String(decoding: requestBody, as: UTF8.self), #"{"message_type":"query.get_health"}"#)

            return (
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!,
                Data(#"{"message_type":"query.get_health.ok","payload":{"status":"ok"}}"#.utf8)
            )
        }

        let response = try await DaemonHTTPTransport.exchange(
            body: Data(#"{"message_type":"query.get_health"}"#.utf8),
            baseURL: URL(string: "https://api.autodev.test")!,
            timeoutSeconds: 1,
            session: session
        )

        XCTAssertEqual(
            String(decoding: response, as: UTF8.self),
            #"{"message_type":"query.get_health.ok","payload":{"status":"ok"}}"#
        )
    }

    func testExchangeMapsNonSuccessStatusToDaemonError() async throws {
        let session = makeMockSession { request in
            (
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 503,
                    httpVersion: nil,
                    headerFields: nil
                )!,
                Data("server unavailable".utf8)
            )
        }

        do {
            _ = try await DaemonHTTPTransport.exchange(
                body: Data("{}".utf8),
                baseURL: URL(string: "https://api.autodev.test")!,
                timeoutSeconds: 1,
                session: session
            )
            XCTFail("Expected requestFailed")
        } catch DaemonClientError.requestFailed(let statusCode, let detail) {
            XCTAssertEqual(statusCode, 503)
            XCTAssertEqual(detail, "server unavailable")
        }
    }

    private func makeMockSession(
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) -> URLSession {
        MockURLProtocol.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private static func bodyData(from request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else {
            return nil
        }
        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 {
                break
            }
            data.append(buffer, count: count)
        }
        return data
    }
}

private final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
