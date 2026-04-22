import Darwin
import Foundation
import XCTest
@testable import AutoDevDesktop

final class DaemonUnixSocketTransportTests: XCTestCase {
    func testExchangeReadsSingleLineResponse() throws {
        let server = try UnixSocketTestServer { fd in
            _ = try Self.readLine(fd: fd)
            try Self.writeAll(fd: fd, data: Data("ok\nextra".utf8))
        }
        defer { server.stop() }

        let response = try DaemonUnixSocketTransport.exchange(
            line: Data("ping\n".utf8),
            socketPath: server.socketPath,
            timeoutSeconds: 1
        )

        XCTAssertEqual(String(decoding: response, as: UTF8.self), "ok")
    }

    func testExchangeTimesOutWhenDaemonDoesNotRespond() throws {
        let server = try UnixSocketTestServer { _ in
            Thread.sleep(forTimeInterval: 0.4)
        }
        defer { server.stop() }

        XCTAssertThrowsError(
            try DaemonUnixSocketTransport.exchange(
                line: Data("ping\n".utf8),
                socketPath: server.socketPath,
                timeoutSeconds: 0.05
            )
        ) { error in
            guard case DaemonClientError.timedOut = error else {
                return XCTFail("Expected timedOut, got \(error)")
            }
        }
    }

    private static func readLine(fd: Int32) throws -> Data {
        var out = Data()
        var byte: UInt8 = 0
        while true {
            let count = Darwin.read(fd, &byte, 1)
            if count < 0 {
                if errno == EINTR {
                    continue
                }
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
            if count == 0 || byte == 0x0A {
                return out
            }
            out.append(byte)
        }
    }

    private static func writeAll(fd: Int32, data: Data) throws {
        let bytes = [UInt8](data)
        var offset = 0
        while offset < bytes.count {
            let written = bytes.withUnsafeBytes { raw in
                Darwin.write(fd, raw.baseAddress!.advanced(by: offset), bytes.count - offset)
            }
            if written < 0 {
                if errno == EINTR {
                    continue
                }
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
            offset += written
        }
    }
}

private final class UnixSocketTestServer {
    let socketPath: String
    private var fd: Int32?
    private let queue = DispatchQueue(label: "DaemonUnixSocketTransportTests.server")

    init(handler: @escaping (Int32) throws -> Void) throws {
        socketPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("autodev-ipc-\(UUID().uuidString).sock")
            .path

        let socketFD = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard socketFD >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        fd = socketFD

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = socketPath.utf8CString
        let pathSize = MemoryLayout.size(ofValue: addr.sun_path)
        guard pathBytes.count <= pathSize else {
            throw POSIXError(.ENAMETOOLONG)
        }

        withUnsafeMutablePointer(to: &addr.sun_path) { sunPath in
            sunPath.withMemoryRebound(to: CChar.self, capacity: pathSize) { dest in
                memset(dest, 0, pathSize)
                for (index, byte) in pathBytes.enumerated() {
                    dest[index] = byte
                }
            }
        }

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(socketFD, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        guard Darwin.listen(socketFD, 1) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }

        queue.async {
            let client = Darwin.accept(socketFD, nil, nil)
            guard client >= 0 else {
                return
            }
            defer { Darwin.close(client) }
            do {
                try handler(client)
            } catch {
                XCTFail("Server handler failed: \(error)")
            }
        }
    }

    func stop() {
        if let fd {
            Darwin.close(fd)
            self.fd = nil
        }
        try? FileManager.default.removeItem(atPath: socketPath)
    }

    deinit {
        stop()
    }
}
