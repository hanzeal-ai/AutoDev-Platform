import Foundation

extension ShellViewModel {
    func upgradeVersion() {
        state.noteUpgradeTapped()
    }

    func openSettings() {
        state.openSettingsPanel()
    }

    func setSettingsPresented(_ isPresented: Bool) {
        state.setSettingsPresented(isPresented)
    }

    func setAppearanceMode(_ mode: AppearanceMode) {
        state.setAppearanceMode(mode)
    }

    func setStorageLocationMode(_ mode: StorageLocationMode) {
        state.setStorageLocationMode(mode)
    }

    func setLocalStoragePath(_ path: String) {
        state.setLocalStoragePath(path)
    }

    func setStageAutomationMode(_ mode: StageAutomationMode) {
        state.setStageAutomationMode(mode)
    }

    func toggleManualConfirmStage(_ stage: DeliveryLifecycleStage) {
        state.toggleManualConfirmStage(stage)
    }

    func setManualSubSteps(_ enabled: Bool) {
        state.setManualSubSteps(enabled)
    }

    func signOut() {
        state.noteSignOutTapped()
    }
}
