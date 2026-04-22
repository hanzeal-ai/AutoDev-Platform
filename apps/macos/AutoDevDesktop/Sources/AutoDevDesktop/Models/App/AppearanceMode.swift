import SwiftUI

enum ShellDataMode: Equatable {
    case sampleOnly
    case liveDaemon
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "跟随系统"
    case light = "亮色"
    case dark = "暗黑"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}
