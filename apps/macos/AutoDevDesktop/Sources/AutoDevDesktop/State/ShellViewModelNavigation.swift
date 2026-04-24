import Foundation

extension ShellViewModel {
    func openOverview() {
        state.openOverview()
    }

    func openProjectLibrary() {
        state.openProjectLibrary()
    }

    func openProjectCreation() {
        switch dataMode {
        case .sampleOnly:
            state.openProjectCreation()
            state.createNewCreationThread()
        case .liveDaemon:
            state.openProjectCreation()
            createNewCreationThread()
        }
    }

    func openProjectDetail(projectID: UUID, from source: ProjectDetailBackTarget) {
        state.openProjectDetail(projectID: projectID, from: source)
        guard dataMode == .liveDaemon else {
            return
        }
        scheduleSelectedProjectDetailRefresh()
    }

    func selectDetailStage(_ stage: DeliveryLifecycleStage) {
        state.selectDetailStage(stage)
        guard dataMode == .liveDaemon else {
            return
        }
        scheduleSelectedProjectDetailRefresh()
    }

    func selectSubStep(_ subStep: String) {
        state.selectSubStep(subStep)
        guard dataMode == .liveDaemon else {
            return
        }
        scheduleSelectedProjectDetailRefresh()
    }

    func triggerStageAction(_ action: String) {
        if shouldPlanDevelopment(for: action) {
            planDevelopmentForSelectedProject()
            return
        }
        if handleStageSupportAction(action) {
            return
        }
        if shouldAdvanceCurrentStage(for: action) {
            advanceSelectedProjectStage(action: action)
            return
        }
        state.triggerStageAction(action)
    }

    func backFromProjectDetail() {
        state.backFromProjectDetail()
    }

    func backToOverview() {
        state.openOverview()
    }

    func deleteProject(projectID: UUID) {
        guard dataMode == .liveDaemon else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                try await daemonClient.deleteProject(projectID: projectID.uuidString)
                state.openProjectLibrary()
                try await refreshOverviewAndProjects()
            } catch {
                state.apply(operationError: error, context: "删除项目")
            }
        }
    }

    private static let sidebarCollapsedKey = "com.sanmws.autodev.sidebarCollapsed"

    func toggleSidebar() {
        state.toggleSidebar()
        UserDefaults.standard.set(state.isSidebarCollapsed, forKey: Self.sidebarCollapsedKey)
    }

    func restoreSidebarState() {
        if UserDefaults.standard.object(forKey: Self.sidebarCollapsedKey) != nil {
            let saved = UserDefaults.standard.bool(forKey: Self.sidebarCollapsedKey)
            if saved != state.isSidebarCollapsed {
                state.toggleSidebar()
            }
        }
    }

    func selectProjectLibraryFilter(_ filter: ProjectLibraryFilter) {
        state.selectProjectLibraryFilter(filter)
    }

    func updateProjectLibrarySearchQuery(_ query: String) {
        state.updateProjectLibrarySearchQuery(query)
    }

    private func shouldPlanDevelopment(for action: String) -> Bool {
        guard state.activeDetailStage == .development else {
            return false
        }
        return action == ShellViewState.defaultPrimaryAction(for: .development)
            || action == state.selectedStagePrimaryAction
            || action.contains("继续")
    }

    private func shouldAdvanceCurrentStage(for action: String) -> Bool {
        guard let project = state.selectedProject, project.status != .completed else {
            return false
        }
        switch state.activeDetailStage {
        case .feasibility:
            return action == state.selectedStagePrimaryAction || action.contains("确认立项")
        case .prd:
            return action == state.selectedStagePrimaryAction || action.contains("进入 UI") || action.contains("确认 PRD")
        case .ui:
            return action == state.selectedStagePrimaryAction || action.contains("进入研发")
        case .development:
            return action.contains("进入测试")
        case .testing:
            return action == state.selectedStagePrimaryAction || action.contains("确认发布")
        case .release:
            return action == state.selectedStagePrimaryAction || action.contains("确认发布")
        case .maintenance:
            return action == state.selectedStagePrimaryAction || action.contains("归档")
        }
    }

    private func handleStageSupportAction(_ action: String) -> Bool {
        if action == "继续讨论" || action == "补充资料" || action == "继续完善 UI" || action == "触发新立项" {
            openProjectCreation()
            state.statusMessage = "已打开项目创建页：\(action)"
            return true
        }

        if action == "查看预览" {
            openStablePreview()
            return true
        }

        if action == "记录问题" {
            openProjectCreation()
            state.statusMessage = "已打开项目创建页，可记录维护问题并触发新一轮需求"
            return true
        }

        return false
    }

    private func openStablePreview() {
        let preview = state.selectedStageDownloads.first {
            $0.title.contains("预览")
        }
        guard let preview else {
            state.statusMessage = "稳定预览尚未生成"
            return
        }
        openStageDownload(preview)
    }

}
