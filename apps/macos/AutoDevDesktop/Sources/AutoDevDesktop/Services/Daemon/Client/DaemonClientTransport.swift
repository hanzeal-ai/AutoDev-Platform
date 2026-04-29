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
            let written = try bytes.withUnsafeBytes { raw -> Int in
                guard let baseAddress = raw.baseAddress else {
                    throw DaemonClientError.writeFailed(code: EINVAL)
                }
                return Darwin.write(fd, baseAddress.advanced(by: offset), bytes.count - offset)
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

// MARK: - Streaming Transport

/// Holds a file descriptor that can be closed from another thread to cancel a blocking read.
final class CancellableSocket: @unchecked Sendable {
    private var fd: Int32 = -1
    private let lock = NSLock()
    private var closed = false

    /// Attach a file descriptor. Must be called before any read begins.
    func attach(fd: Int32) {
        lock.lock()
        defer { lock.unlock() }
        self.fd = fd
        // If cancel was called before attach, shut down immediately
        if closed && fd >= 0 {
            Darwin.shutdown(fd, SHUT_RDWR)
        }
    }

    /// Close the socket from any thread, causing blocking reads to fail.
    func cancel() {
        lock.lock()
        defer { lock.unlock() }
        guard !closed else { return }
        closed = true
        if fd >= 0 {
            Darwin.shutdown(fd, SHUT_RDWR)
        }
    }

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return closed
    }
}

extension DaemonUnixSocketTransport {
    /// Send a request and read multiple line-delimited JSON responses (streaming).
    /// The provided CancellableSocket can be used to abort from another thread.
    static func exchangeStreaming(
        line: Data,
        socketPath: String,
        cancelHandle: CancellableSocket,
        timeoutSeconds: TimeInterval = 120,
        onLine: @escaping (Data) throws -> Bool // return false to stop
    ) throws {
        let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw DaemonClientError.socketCreateFailed
        }
        defer { Darwin.close(fd) }

        cancelHandle.attach(fd: fd)

        // If already cancelled before we even connected, bail out
        guard !cancelHandle.isCancelled else { return }

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
            if cancelHandle.isCancelled { return }
            throw DaemonClientError.connectFailed(code: errno)
        }

        do {
            try configureTimeout(fd: fd, seconds: timeoutSeconds)
            try writeAll(fd: fd, data: line)
            try readLinesUntilDone(fd: fd, onLine: onLine)
        } catch {
            // If cancelled, swallow the error silently
            if cancelHandle.isCancelled { return }
            throw error
        }
    }

    private static func readLinesUntilDone(
        fd: Int32,
        onLine: (Data) throws -> Bool
    ) throws {
        var buffer = Data()
        var readBuf = [UInt8](repeating: 0, count: 4096)

        while true {
            let readCount = Darwin.read(fd, &readBuf, readBuf.count)
            if readCount < 0 {
                if errno == EINTR { continue }
                if errno == EAGAIN || errno == EWOULDBLOCK {
                    throw DaemonClientError.timedOut
                }
                throw DaemonClientError.readFailed(code: errno)
            }
            if readCount == 0 {
                if !buffer.isEmpty {
                    let shouldContinue = try onLine(buffer)
                    if !shouldContinue {
                        return
                    }
                }
                break
            }

            buffer.append(contentsOf: readBuf.prefix(readCount))

            // Process complete lines
            while let nlIndex = buffer.firstIndex(of: 0x0A) {
                let lineData = buffer.prefix(upTo: nlIndex)
                buffer = Data(buffer.suffix(from: buffer.index(after: nlIndex)))

                if lineData.isEmpty { continue }
                let shouldContinue = try onLine(Data(lineData))
                if !shouldContinue { return }
            }
        }
    }
}
