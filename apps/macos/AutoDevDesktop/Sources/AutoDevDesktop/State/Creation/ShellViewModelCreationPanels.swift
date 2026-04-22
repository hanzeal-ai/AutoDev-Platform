import Foundation

extension ShellViewModel {
    func toggleCreationThreadPanel() {
        state.toggleCreationThreadPanel()
    }

    func toggleReportPanel() {
        state.toggleReportPanel()
    }

    func setMaterialImporterPresented(_ isPresented: Bool) {
        state.setMaterialImporterPresented(isPresented)
    }

    func resolveActiveCreationThreadIDAfterRefresh(expectedThreadID: UUID? = nil) async throws -> UUID {
        guard let originalThreadID = expectedThreadID ?? state.selectedEffectiveCreationThreadID else {
            throw CreationThreadSelectionError.invalidSelectedThread
        }

        try await refreshCreationThreads()

        if state.creationThreads.contains(where: { $0.id == originalThreadID && !$0.isArchived }) {
            state.selectCreationThread(originalThreadID)
            return originalThreadID
        }

        if let fallbackThread = state.creationThreads.first(where: { !$0.isArchived }) {
            state.selectCreationThread(fallbackThread.id)
            return fallbackThread.id
        }

        throw CreationThreadSelectionError.invalidSelectedThread
    }
}

enum CreationThreadSelectionError: LocalizedError {
    case invalidSelectedThread

    var errorDescription: String? {
        switch self {
        case .invalidSelectedThread:
            return "当前线程已失效，请重新选择线程后重试。"
        }
    }
}
