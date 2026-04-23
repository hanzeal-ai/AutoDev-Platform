import SwiftUI

enum AutoDevViewTheme {
    static let pageSpacing: CGFloat = 14
    static let cardSpacing: CGFloat = 10
    static let compactSpacing: CGFloat = 8

    static func daemonStatusColor(_ status: String) -> Color {
        switch status {
        case "OK":
            return .green
        case "PREVIEW":
            return .orange
        default:
            return .red
        }
    }
}

extension ShellRoute {
    var isOverview: Bool {
        if case .overview = self {
            return true
        }
        return false
    }

    var isProjectDetail: Bool {
        if case .projectDetail = self {
            return true
        }
        return false
    }

    var isProjectCreation: Bool {
        if case .projectCreation = self {
            return true
        }
        return false
    }

    var isProjectLibraryOrCreation: Bool {
        switch self {
        case .projectLibrary, .projectCreation:
            return true
        default:
            return false
        }
    }
}

extension ProjectStatus {
    var color: Color {
        switch self {
        case .running:
            return .orange
        case .queued:
            return .blue
        case .awaitingConfirmation:
            return .cyan
        case .blocked, .failed:
            return .red
        case .completed, .archived:
            return .green
        }
    }
}

extension ProjectRisk {
    var color: Color {
        switch self {
        case .low:
            return .green
        case .medium:
            return .orange
        case .high:
            return .red
        }
    }
}

extension InterventionPriority {
    var color: Color {
        switch self {
        case .critical:
            return .red
        case .normal:
            return .orange
        case .low:
            return .blue
        }
    }
}

extension AlertLevel {
    var color: Color {
        switch self {
        case .warning:
            return .orange
        case .critical:
            return .red
        case .info:
            return .blue
        }
    }
}
