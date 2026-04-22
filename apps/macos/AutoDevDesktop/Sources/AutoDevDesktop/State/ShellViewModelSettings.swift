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

    func signOut() {
        state.noteSignOutTapped()
    }
}
