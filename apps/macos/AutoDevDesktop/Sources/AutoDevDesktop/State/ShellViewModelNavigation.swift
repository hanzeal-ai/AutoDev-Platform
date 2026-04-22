import Foundation

extension ShellViewModel {
    func openOverview() {
        state.openOverview()
    }

    func openProjectLibrary() {
        state.openProjectLibrary()
    }

    func openProjectCreation() {
        state.openProjectCreation()
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

    func triggerStageAction(_ action: String) {
        if shouldPlanDevelopment(for: action) {
            planDevelopmentForSelectedProject()
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

    func toggleSidebar() {
        state.toggleSidebar()
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

    private func planDevelopmentForSelectedProject() {
        guard let projectID = state.selectedProject?.id else {
            state.triggerStageAction(ShellViewState.defaultPrimaryAction(for: .development))
            return
        }

        switch dataMode {
        case .sampleOnly:
            guard !isPlanningDevelopment else { return }
            isPlanningDevelopment = true
            developmentSimulationTask?.cancel()
            startDevelopmentSimulation(projectID: projectID, shouldEndInCoding: true)
        case .liveDaemon:
            guard !isPlanningDevelopment else { return }
            isPlanningDevelopment = true
            developmentSimulationTask?.cancel()
            Task { @MainActor in
                defer { isPlanningDevelopment = false }
                do {
                    state.statusMessage = "研发规划模拟启动"
                    startDevelopmentSimulation(projectID: projectID, shouldEndInCoding: false)
                    try await Task.sleep(nanoseconds: 3_200_000_000)
                    guard !Task.isCancelled else { return }
                    _ = try await daemonClient.planDevelopment(projectID: projectID.uuidString)
                    await refreshSelectedProjectDetail()
                    state.statusMessage = "研发规划完成，进入编码阶段"
                } catch {
                    state.apply(operationError: error, context: "继续推进")
                }
            }
        }
    }

    private func startDevelopmentSimulation(projectID: UUID, shouldEndInCoding: Bool) {
        let detail = state.selectedExecutionDetail ?? makeDevelopmentSimulationDetail(projectID: projectID)

        let key = ProjectExecutionDetailKey(projectID: projectID, stage: .development)
        developmentSimulationTask = Task { @MainActor [weak self] in
            let stages: [[DeliveryWorkUnitItem]] = [
                Self.simulatedWorkUnits(active: "input-consolidation"),
                Self.simulatedWorkUnits(active: "api-contract"),
                Self.simulatedWorkUnits(active: "frontend-backend-task-split"),
                Self.simulatedWorkUnits(active: "implementation-review-test"),
            ]

            for units in stages {
                guard !Task.isCancelled else { return }
                self?.state.executionDetails[key] = detail.withUpdatedWorkUnits(units)
                self?.state.statusMessage = "研发规划模拟推进中"
                try? await Task.sleep(nanoseconds: 750_000_000)
            }

            guard shouldEndInCoding, !Task.isCancelled else { return }
            self?.state.executionDetails[key] = detail.withUpdatedWorkUnits(Self.simulatedWorkUnits(active: "implementation-review-test"))
            self?.state.statusMessage = "研发规划完成，进入编码阶段"
            self?.isPlanningDevelopment = false
        }
    }

    private func makeDevelopmentSimulationDetail(projectID: UUID) -> DeliveryExecutionDetail {
        let project = state.projects.first(where: { $0.id == projectID })
        return DeliveryExecutionDetail(
            unitName: "\(project?.title ?? "项目") / 研发执行单元",
            projectName: project?.title ?? "项目",
            lifecycleStage: .development,
            status: .running,
            priority: "中",
            owner: "系统代理",
            updatedAt: "刚刚",
            objective: "模拟研发规划执行过程",
            inputContexts: [],
            outputArtifacts: [],
            stepProgress: [],
            riskLevel: .medium,
            blockerReason: nil,
            needsUserIntervention: false,
            events: [],
            riskItems: [],
            primaryAction: "继续实现",
            secondaryActions: ["进入测试"],
            downloads: [],
            workUnits: Self.simulatedWorkUnits(active: "input-consolidation")
        )
    }

    private static func simulatedWorkUnits(active: String) -> [DeliveryWorkUnitItem] {
        func status(_ id: String) -> ProjectStatus {
            if id == active { return .running }
            let order = ["input-consolidation", "api-contract", "frontend-backend-task-split", "implementation-review-test"]
            let activeIndex = order.firstIndex(of: active) ?? 0
            let index = order.firstIndex(of: id) ?? 0
            return index < activeIndex ? .completed : .blocked
        }
        func progress(_ id: String) -> Double {
            switch status(id) {
            case .completed:
                return 1
            case .running:
                return 0.55
            default:
                return 0
            }
        }

        return [
            DeliveryWorkUnitItem(
                id: "input-consolidation",
                title: "项目输入收敛",
                agentRole: "规划 Agent",
                status: status("input-consolidation"),
                progress: progress("input-consolidation"),
                dependsOn: [],
                currentOutput: "项目输入快照",
                nextStep: status("input-consolidation") == .completed ? "已完成" : "整理项目输入",
                downloads: []
            ),
            DeliveryWorkUnitItem(
                id: "api-contract",
                title: "接口契约生成",
                agentRole: "契约规划 Agent",
                status: status("api-contract"),
                progress: progress("api-contract"),
                dependsOn: ["input-consolidation"],
                currentOutput: status("api-contract") == .completed ? "api-contract.md" : nil,
                nextStep: status("api-contract") == .blocked ? "等待项目输入" : "冻结接口契约",
                downloads: []
            ),
            DeliveryWorkUnitItem(
                id: "frontend-backend-task-split",
                title: "前后端任务拆分",
                agentRole: "任务拆分 Agent",
                status: status("frontend-backend-task-split"),
                progress: progress("frontend-backend-task-split"),
                dependsOn: ["input-consolidation", "api-contract"],
                currentOutput: status("frontend-backend-task-split") == .completed ? "frontend-tasks.md / backend-tasks.md" : nil,
                nextStep: status("frontend-backend-task-split") == .blocked ? "等待接口契约" : "生成前后端任务拆分",
                downloads: []
            ),
            DeliveryWorkUnitItem(
                id: "implementation-review-test",
                title: "编码阶段准备",
                agentRole: "实现 Agent",
                status: status("implementation-review-test"),
                progress: progress("implementation-review-test"),
                dependsOn: ["frontend-backend-task-split"],
                currentOutput: status("implementation-review-test") == .running ? "编码启动清单准备中" : nil,
                nextStep: "完成准备后进入正式编码循环",
                downloads: []
            ),
        ]
    }
}

private extension DeliveryExecutionDetail {
    func withUpdatedWorkUnits(_ workUnits: [DeliveryWorkUnitItem]) -> DeliveryExecutionDetail {
        var copy = self
        copy.workUnits = workUnits
        copy.primaryAction = "继续实现"
        return copy
    }
}
