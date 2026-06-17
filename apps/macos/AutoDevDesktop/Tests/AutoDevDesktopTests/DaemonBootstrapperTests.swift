import Foundation
import XCTest
@testable import AutoDevDesktop

final class DaemonBootstrapperTests: XCTestCase {
    func testLocalServicesLaunchForLoopbackAPI() {
        XCTAssertTrue(DaemonBootstrapper.shouldLaunchLocalServices(
            apiBaseURL: URL(string: "http://127.0.0.1:7373")!
        ))
        XCTAssertTrue(DaemonBootstrapper.shouldLaunchLocalServices(
            apiBaseURL: URL(string: "http://localhost:7373")!
        ))
    }

    func testLocalServicesDoNotLaunchForRemoteAPI() {
        XCTAssertFalse(DaemonBootstrapper.shouldLaunchLocalServices(
            apiBaseURL: URL(string: "https://api.autodev.example")!
        ))
    }
}
