import Foundation

extension ShellViewState {
    var projectLibraryProjects: [DeliveryProjectItem] {
        let filteredByStatus: [DeliveryProjectItem]
        switch projectLibraryFilter {
        case .inProgress:
            filteredByStatus = projects.filter { Self.runningStatuses.contains($0.status) }
        case .all:
            filteredByStatus = projects
        case .blocked:
            filteredByStatus = projects.filter { [.blocked, .failed].contains($0.status) }
        case .archived:
            filteredByStatus = projects.filter { Self.closedStatuses.contains($0.status) }
        }

        let keyword = projectLibrarySearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            return filteredByStatus
        }

        return filteredByStatus.filter { project in
            project.title.localizedCaseInsensitiveContains(keyword) ||
                project.currentPhase.localizedCaseInsensitiveContains(keyword) ||
                project.status.rawValue.localizedCaseInsensitiveContains(keyword)
        }
    }

    var projectLibraryCounts: [ProjectLibraryFilter: Int] {
        [
            .all: projects.count,
            .inProgress: projects.filter { Self.runningStatuses.contains($0.status) }.count,
            .blocked: projects.filter { [.blocked, .failed].contains($0.status) }.count,
            .archived: projects.filter { Self.closedStatuses.contains($0.status) }.count,
        ]
    }
}
