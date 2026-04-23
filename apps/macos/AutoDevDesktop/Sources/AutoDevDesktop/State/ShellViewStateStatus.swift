import Foundation

extension ShellViewState {
    mutating func apply(health: DaemonHealth) {
        daemonStatus = health.status.uppercased()
        daemonVersion = health.daemonVersion
        protocolVersion = "\(health.protocolVersion)"
        if health.deepseekConfigured == true {
            let trimmedModel = health.deepseekModel?.trimmingCharacters(in: .whitespacesAndNewlines)
            let model = trimmedModel.flatMap({ $0.isEmpty ? nil : $0 }) ?? "deepseek-chat"
            deepseekStatusLine = "DeepSeek 已接入 · \(model)"
        } else {
            deepseekStatusLine = "DeepSeek 未配置"
        }
        lastError = "-"
        statusMessage = "系统运行中"
    }

    mutating func applySampleRefresh() {
        daemonStatus = "PREVIEW"
        daemonVersion = "-"
        protocolVersion = "-"
        deepseekStatusLine = "DeepSeek 预览模式"
        lastError = "-"
        statusMessage = "空预览状态"
    }

    mutating func apply(error: Error) {
        daemonStatus = "OFFLINE"
        daemonVersion = "-"
        protocolVersion = "-"
        deepseekStatusLine = "DeepSeek 未连接"
        lastError = error.localizedDescription
        statusMessage = "系统离线"
        StructuredLogWriter.write(component: "autodev-app", level: "ERROR", message: "daemon error: \(error.localizedDescription)")
    }

    mutating func apply(operationError error: Error, context: String) {
        lastError = error.localizedDescription
        statusMessage = "\(context)失败：\(error.localizedDescription)"
        StructuredLogWriter.write(component: "autodev-app", level: "ERROR", message: "\(context) failed: \(error.localizedDescription)")
    }

    mutating func noteUpgradeTapped() {
        statusMessage = "升级入口已触发，等待后端提供套餐与支付能力。"
    }

    mutating func noteSettingsTapped() {
        statusMessage = "设置入口已触发，等待后端提供偏好配置读写。"
    }

    mutating func openSettingsPanel() {
        isSettingsPresented = true
    }

    mutating func setSettingsPresented(_ isPresented: Bool) {
        isSettingsPresented = isPresented
    }

    mutating func setAppearanceMode(_ mode: AppearanceMode) {
        appearanceMode = mode
    }

    mutating func setStorageLocationMode(_ mode: StorageLocationMode) {
        storageLocationMode = mode
        mode.save()
    }

    mutating func setLocalStoragePath(_ path: String) {
        localStoragePath = path
        StorageLocationMode.saveLocalPath(path)
    }

    mutating func setStageAutomationMode(_ mode: StageAutomationMode) {
        stageAutomation.mode = mode
        stageAutomation.save()
    }

    mutating func toggleManualConfirmStage(_ stage: DeliveryLifecycleStage) {
        if stageAutomation.manualConfirmStages.contains(stage) {
            stageAutomation.manualConfirmStages.remove(stage)
        } else {
            stageAutomation.manualConfirmStages.insert(stage)
        }
        stageAutomation.save()
    }

    mutating func setManualSubSteps(_ enabled: Bool) {
        stageAutomation.manualSubSteps = enabled
        stageAutomation.save()
    }

    mutating func triggerStageAction(_ action: String) {
        statusMessage = "阶段动作已触发：\(action)"
    }

    mutating func noteSignOutTapped() {
        statusMessage = "退出登录动作已触发，等待认证模块接入。"
    }
}
