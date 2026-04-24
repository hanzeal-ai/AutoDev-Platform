import Foundation

extension ShellViewState {
    mutating func openOverview() {
        route = .overview
    }

    mutating func openProjectLibrary() {
        route = .projectLibrary
    }

    mutating func openProjectCreation() {
        route = .projectCreation
        selectedCreationThreadID = nil
        selectedCreationThreadIndex = nil
    }

    mutating func openProjectDetail(projectID: UUID, from source: ProjectDetailBackTarget) {
        route = .projectDetail(projectID: projectID)
        projectDetailBackTarget = source
        selectedDetailStage = projects.first(where: { $0.id == projectID })?.lifecycleStage
    }

    mutating func backFromProjectDetail() {
        switch projectDetailBackTarget {
        case .overview:
            route = .overview
        case .projectLibrary:
            route = .projectLibrary
        }
    }

    mutating func selectDetailStage(_ stage: DeliveryLifecycleStage) {
        selectedDetailStage = stage
        selectedSubStep = nil
    }

    mutating func selectSubStep(_ subStep: String) {
        selectedSubStep = subStep
    }

    mutating func toggleSidebar() {
        isSidebarCollapsed.toggle()
    }

    mutating func selectProjectLibraryFilter(_ filter: ProjectLibraryFilter) {
        projectLibraryFilter = filter
    }

    mutating func updateProjectLibrarySearchQuery(_ query: String) {
        projectLibrarySearchQuery = query
    }
}
