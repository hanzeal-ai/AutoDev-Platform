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

    func dismissError() {
        state.dismissError()
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

    func updateLoginUsername(_ username: String) {
        state.loginUsername = username
        state.loginError = ""
    }

    func updateLoginPassword(_ password: String) {
        state.loginPassword = password
        state.loginError = ""
    }

    func signIn() {
        let username = state.loginUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = state.loginPassword
        guard !username.isEmpty, !password.isEmpty else {
            state.applyLoginError("请输入账号和密码")
            return
        }
        guard !isChecking else { return }

        isChecking = true
        Task { [weak self] in
            guard let self else { return }
            defer { isChecking = false }
            do {
                let user = try await daemonClient.login(username: username, password: password)
                state.applyLogin(user: UserProfileSummary(daemonUser: user))
                if dataMode == .liveDaemon {
                    try await refreshLiveSnapshot()
                }
            } catch {
                state.applyLoginError(loginErrorMessage(error))
            }
        }
    }

    private func loginErrorMessage(_ error: Error) -> String {
        if case let DaemonClientError.daemonError(_, detail) = error {
            return detail
        }
        return error.localizedDescription
    }
}
