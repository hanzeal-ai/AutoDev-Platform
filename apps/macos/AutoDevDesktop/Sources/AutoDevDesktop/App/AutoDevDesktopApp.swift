import AppKit
import SwiftUI

@main
struct AutoDevDesktopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel = ShellViewModel(dataMode: .liveDaemon)

    var body: some Scene {
        WindowGroup("AI AutoDev Desktop") {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 1120, minHeight: 720)
        }
    }
}
