import Darwin
import Foundation

enum DaemonUnixSocketTransport {
    static func exchange(line: Data, socketPath: String, timeoutSeconds: TimeInterval = 5) throws -> Data {
        try withConnectedSocket(socketPath: socketPath) { fd in
            try configureTimeout(fd: fd, seconds: timeoutSeconds)
            try writeAll(fd: fd, data: line)
            return try readLine(fd: fd)
        }
    }

    private static func withConnectedSocket<T>(socketPath: String, _ body: (Int32) throws -> T) throws -> T {
        let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw DaemonClientError.socketCreateFailed
        }
        defer { Darwin.close(fd) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        let pathBytes = socketPath.utf8CString
        let pathSize = MemoryLayout.size(ofValue: addr.sun_path)
        guard pathBytes.count <= pathSize else {
            throw DaemonClientError.socketPathTooLong
        }

        withUnsafeMutablePointer(to: &addr.sun_path) { sunPath in
            sunPath.withMemoryRebound(to: CChar.self, capacity: pathSize) { dest in
                memset(dest, 0, pathSize)
                for (index, byte) in pathBytes.enumerated() {
                    dest[index] = byte
                }
            }
        }

        let connectResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        if connectResult != 0 {
            throw DaemonClientError.connectFailed(code: errno)
        }

        return try body(fd)
    }

    private static func configureTimeout(fd: Int32, seconds: TimeInterval) throws {
        let wholeSeconds = Int(seconds)
        let microseconds = Int((seconds - Double(wholeSeconds)) * 1_000_000)
        var timeout = timeval(tv_sec: wholeSeconds, tv_usec: Int32(microseconds))
        let size = socklen_t(MemoryLayout<timeval>.size)

        let sendResult = withUnsafePointer(to: &timeout) { pointer in
            pointer.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<timeval>.size) {
                Darwin.setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, $0, size)
            }
        }
        guard sendResult == 0 else {
            throw DaemonClientError.writeFailed(code: errno)
        }

        let receiveResult = withUnsafePointer(to: &timeout) { pointer in
            pointer.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<timeval>.size) {
                Darwin.setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, $0, size)
            }
        }
        guard receiveResult == 0 else {
            throw DaemonClientError.readFailed(code: errno)
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
                if errno == EAGAIN || errno == EWOULDBLOCK {
                    throw DaemonClientError.timedOut
                }
                throw DaemonClientError.writeFailed(code: errno)
            }
            guard written > 0 else {
                throw DaemonClientError.connectionClosed
            }
            offset += written
        }
    }

    private static func readLine(fd: Int32) throws -> Data {
        var out = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)

        while true {
            let readCount = Darwin.read(fd, &buffer, buffer.count)
            if readCount < 0 {
                if errno == EINTR {
                    continue
                }
                if errno == EAGAIN || errno == EWOULDBLOCK {
                    throw DaemonClientError.timedOut
                }
                throw DaemonClientError.readFailed(code: errno)
            }
            if readCount == 0 {
                break
            }

            let slice = buffer.prefix(readCount)
            if let nl = slice.firstIndex(of: 0x0A) {
                out.append(contentsOf: slice.prefix(upTo: nl))
                break
            }

            out.append(contentsOf: slice)
        }

        guard !out.isEmpty else {
            throw DaemonClientError.emptyResponse
        }
        return out
    }
}
