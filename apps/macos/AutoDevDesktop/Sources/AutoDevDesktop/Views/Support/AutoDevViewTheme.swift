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

    static func daemonStatusIcon(_ status: String) -> String {
        switch status {
        case "OK":
            return "checkmark.circle.fill"
        case "PREVIEW":
            return "eye.circle.fill"
        default:
            return "xmark.circle.fill"
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

    var icon: String {
        switch self {
        case .running:
            return "arrow.triangle.2.circlepath"
        case .queued:
            return "clock"
        case .awaitingConfirmation:
            return "hand.raised"
        case .blocked:
            return "exclamationmark.triangle"
        case .failed:
            return "xmark.circle"
        case .completed:
            return "checkmark.circle"
        case .archived:
            return "archivebox"
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

    var icon: String {
        switch self {
        case .critical:
            return "exclamationmark.triangle.fill"
        case .normal:
            return "flag.fill"
        case .low:
            return "info.circle"
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

    var icon: String {
        switch self {
        case .warning:
            return "exclamationmark.triangle.fill"
        case .critical:
            return "xmark.octagon.fill"
        case .info:
            return "info.circle.fill"
        }
    }
}
