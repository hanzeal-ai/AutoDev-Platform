import Foundation

extension ShellViewModel {
    func advanceSelectedProjectStage(action: String) {
        guard let projectID = state.selectedProject?.id else {
            state.triggerStageAction(action)
            return
        }

        switch dataMode {
        case .sampleOnly:
            advanceSelectedProjectLocally(projectID: projectID)
            state.triggerStageAction(action)
        case .liveDaemon:
            let currentStage = state.activeDetailStage
            let nextStage = nextStage(after: currentStage)
            let autoTriggerAI: Bool
            if let next = nextStage {
                autoTriggerAI = state.stageAutomation.shouldAutoTriggerAI(for: next)
            } else {
                autoTriggerAI = false
            }
            Task { [weak self] in
                guard let self else { return }
                do {
                    _ = try await daemonClient.advanceProjectStage(
                        projectID: projectID.uuidString,
                        action: action,
                        autoTriggerAI: autoTriggerAI
                    )
                    try await refreshOverviewAndProjects()
                    if let stage = state.selectedProject?.lifecycleStage {
                        state.selectDetailStage(stage)
                    }
                    await refreshSelectedProjectDetail()
                    state.statusMessage = "阶段已推进：\(action)"

                    if autoTriggerAI, let next = nextStage {
                        startAutoAdvancePolling(projectID: projectID, stage: next)
                    }
                } catch {
                    state.apply(operationError: error, context: action)
                }
            }
        }
    }

    private func startAutoAdvancePolling(projectID: UUID, stage: DeliveryLifecycleStage) {
        guard autoAdvanceDepth < Self.maxAutoAdvanceDepth else {
            state.statusMessage = "已达到自动推进上限（\(Self.maxAutoAdvanceDepth) 个阶段），请手动确认后继续"
            autoAdvanceDepth = 0
            return
        }
        autoAdvanceTask?.cancel()
        autoAdvanceTask = Task { @MainActor [weak self] in
            let maxPolls = 120
            var pollDelay: UInt64 = 2_000_000_000
            let maxDelay: UInt64 = 5_000_000_000
            for _ in 0..<maxPolls {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(nanoseconds: pollDelay)
                guard !Task.isCancelled else { return }
                guard let self,
                      self.state.selectedProject?.id == projectID,
                      self.state.activeDetailStage == stage
                else { return }

                await self.refreshSelectedProjectDetail()

                let key = ProjectExecutionDetailKey(projectID: projectID, stage: stage)
                if let detail = self.state.executionDetails[key],
                   let aiRun = detail.aiRun, !aiRun.isActive
                {
                    if aiRun.status == "completed",
                       !self.state.stageAutomation.stageNeedsConfirmation(stage),
                       self.nextStage(after: stage) != nil
                    {
                        self.autoAdvanceDepth += 1
                        self.advanceSelectedProjectStage(
                            action: ShellViewState.defaultPrimaryAction(for: stage)
                        )
                    } else {
                        self.autoAdvanceDepth = 0
                    }
                    return
                }
                pollDelay = min(pollDelay + 500_000_000, maxDelay)
            }
            self?.autoAdvanceDepth = 0
        }
    }

    private func advanceSelectedProjectLocally(projectID: UUID) {
        guard let projectIndex = state.projects.firstIndex(where: { $0.id == projectID }),
              let nextStage = nextStage(after: state.projects[projectIndex].lifecycleStage)
        else {
            return
        }
        state.projects[projectIndex].lifecycleStage = nextStage
        state.projects[projectIndex].currentPhase = nextStage.rawValue
        state.projects[projectIndex].status = .awaitingConfirmation
        state.projects[projectIndex].progress = defaultProgress(for: nextStage)
        state.projects[projectIndex].currentGoal = defaultGoal(for: nextStage)
        state.projects[projectIndex].nextAction = defaultNextAction(for: nextStage)
        state.projects[projectIndex].updateTime = "刚刚"
        state.selectDetailStage(nextStage)
    }

    private func nextStage(after stage: DeliveryLifecycleStage) -> DeliveryLifecycleStage? {
        switch stage {
        case .feasibility:
            return .prd
        case .prd:
            return .ui
        case .ui:
            return .development
        case .development:
            return .testing
        case .testing:
            return .release
        case .release:
            return .maintenance
        case .maintenance:
            return nil
        }
    }

    private func defaultProgress(for stage: DeliveryLifecycleStage) -> Double {
        switch stage {
        case .feasibility:
            return 0.08
        case .prd:
            return 0.12
        case .ui:
            return 0.28
        case .development:
            return 0.45
        case .testing:
            return 0.72
        case .release:
            return 0.9
        case .maintenance:
            return 1
        }
    }

    private func defaultGoal(for stage: DeliveryLifecycleStage) -> String {
        switch stage {
        case .feasibility:
            return "完成可行性判断并形成受控立项决策"
        case .prd:
            return "冻结 PRD 范围边界、功能拆分与验收标准"
        case .ui:
            return "完成页面地图、交互流与关键组件定义"
        case .development:
            return "完成前后端任务拆分、编码审查循环与稳定预览交付"
        case .testing:
            return "验证质量门禁并形成发布准入结论"
        case .release:
            return "完成发布准备、执行与回滚保障"
        case .maintenance:
            return "监控运行健康并沉淀下一轮优化建议"
        }
    }

    private func defaultNextAction(for stage: DeliveryLifecycleStage) -> String {
        switch stage {
        case .feasibility:
            return "确认立项"
        case .prd:
            return "确认 PRD 后进入 UI 阶段"
        case .ui:
            return "当前联调可跳过 UI 并进入研发阶段"
        case .development:
            return "继续推进研发规划与编码准备"
        case .testing:
            return "确认质量门禁后进入发布阶段"
        case .release:
            return "确认发布后进入维护阶段"
        case .maintenance:
            return "查看维护记录与归档"
        }
    }

    func planDevelopmentForSelectedProject() {
        guard let projectID = state.selectedProject?.id else {
            state.triggerStageAction(ShellViewState.defaultPrimaryAction(for: .development))
            return
        }

        switch dataMode {
        case .sampleOnly:
            state.triggerStageAction(ShellViewState.defaultPrimaryAction(for: .development))
        case .liveDaemon:
            guard !isPlanningDevelopment else { return }
            isPlanningDevelopment = true
            Task { [weak self] in
                guard let self else { return }
                defer { isPlanningDevelopment = false }
                do {
                    state.statusMessage = "研发规划启动"
                    _ = try await daemonClient.planDevelopment(projectID: projectID.uuidString)
                    await refreshSelectedProjectDetail()
                    state.statusMessage = "研发规划完成，进入编码阶段"
                } catch {
                    state.apply(operationError: error, context: "继续推进")
                }
            }
        }
    }
}
