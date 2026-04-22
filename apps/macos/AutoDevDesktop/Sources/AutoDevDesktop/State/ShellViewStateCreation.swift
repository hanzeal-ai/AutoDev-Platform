import Foundation

extension ShellViewState {
    mutating func replaceCreationThreads(_ threads: [CreationThreadSession]) {
        creationThreads = threads
        resortCreationThreads()
        syncSelectedCreationThread(preferredID: selectedCreationThreadID)
    }

    mutating func toggleCreationThreadPanel() {
        isCreationThreadPanelCollapsed.toggle()
    }

    mutating func toggleReportPanel() {
        isReportPanelCollapsed.toggle()
    }

    mutating func setMaterialImporterPresented(_ isPresented: Bool) {
        isMaterialImporterPresented = isPresented
    }

    mutating func selectCreationThread(_ threadID: UUID) {
        syncSelectedCreationThread(preferredID: threadID)
    }

    mutating func updateCreationInputDraft(_ input: String) {
        creationInputDraft = input
    }

    mutating func requestCreationInputInsertion(_ reference: String) {
        let trimmedReference = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedReference.isEmpty else { return }
        creationInputInsertionRequest = CreationInputInsertionRequest(
            id: UUID(),
            text: trimmedReference
        )
    }

    mutating func clearCreationInputInsertionRequest() {
        creationInputInsertionRequest = nil
    }

    mutating func addCreationMaterials(urls: [URL]) {
        guard let threadID = selectedCreationThreadID else {
            return
        }
        guard let index = creationThreads.firstIndex(where: { $0.id == threadID }) else {
            return
        }
        let items = urls.map { url in
            CreationMaterialItem(
                id: UUID(),
                name: url.lastPathComponent,
                typeHint: url.pathExtension.isEmpty ? "资料" : url.pathExtension.uppercased(),
                sizeHint: "待识别",
                addedAt: "刚刚",
                status: .queued
            )
        }
        creationThreads[index].materials.insert(contentsOf: items, at: 0)
        creationThreads[index].lastUpdated = "刚刚"
        resortCreationThreads()
        syncSelectedCreationThread(preferredID: threadID)
    }

    mutating func removeCreationMaterial(_ materialID: UUID) {
        guard let threadID = selectedCreationThreadID else {
            return
        }
        guard let index = creationThreads.firstIndex(where: { $0.id == threadID }) else {
            return
        }
        creationThreads[index].materials.removeAll { $0.id == materialID }
        syncSelectedCreationThread(preferredID: threadID)
    }

    mutating func createNewCreationThread() {
        statusMessage = "预览模式不支持创建线程"
    }

    mutating func archiveCreationThread(_ threadID: UUID) {
        guard let index = creationThreads.firstIndex(where: { $0.id == threadID }) else {
            return
        }
        creationThreads[index].isArchived = true
        creationThreads[index].lastUpdated = "刚刚"
        resortCreationThreads()
        syncSelectedCreationThread(preferredID: threadID)
    }

    mutating func deleteCreationThread(_ threadID: UUID) {
        guard let index = creationThreads.firstIndex(where: { $0.id == threadID }) else {
            return
        }
        creationThreads.remove(at: index)
        let preferredID = selectedCreationThreadID == threadID ? nil : selectedCreationThreadID
        syncSelectedCreationThread(preferredID: preferredID)
        if let renameThreadTargetID = renameThreadTargetID, renameThreadTargetID == threadID {
            self.renameThreadTargetID = nil
            renameThreadDraft = ""
        }
    }

    mutating func beginRenameCreationThread(_ threadID: UUID) {
        guard let thread = creationThreads.first(where: { $0.id == threadID }) else {
            return
        }
        renameThreadTargetID = thread.id
        renameThreadDraft = thread.title
    }

    mutating func updateRenameThreadDraft(_ title: String) {
        renameThreadDraft = title
    }

    mutating func applyRenameCreationThread() {
        let trimmed = renameThreadDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let renameThreadTargetID = renameThreadTargetID else {
            return
        }
        guard let index = creationThreads.firstIndex(where: { $0.id == renameThreadTargetID }) else {
            return
        }
        creationThreads[index].title = trimmed
        creationThreads[index].lastUpdated = "刚刚"
        resortCreationThreads()
        syncSelectedCreationThread(preferredID: renameThreadTargetID)
        self.renameThreadTargetID = nil
        renameThreadDraft = ""
    }

    mutating func dismissRenameCreationThread() {
        renameThreadTargetID = nil
        renameThreadDraft = ""
    }

    mutating func confirmFeasibilityAndEnterPRD() {
        statusMessage = "预览模式不支持确认立项"
    }

    mutating func sendCreationInput() {
        creationInputDraft = ""
        statusMessage = "预览模式不支持发送消息"
    }

    private mutating func resortCreationThreads() {
        creationThreads.sort(by: Self.isCreationThreadOrderedBefore(_:_:))
    }

    private mutating func syncSelectedCreationThread(preferredID: UUID?) {
        guard !creationThreads.isEmpty else {
            selectedCreationThreadID = nil
            selectedCreationThreadIndex = nil
            return
        }

        if let targetID = preferredID ?? selectedCreationThreadID,
           let index = creationThreads.firstIndex(where: { $0.id == targetID })
        {
            let thread = creationThreads[index]
            if !thread.isArchived {
                selectedCreationThreadID = targetID
                selectedCreationThreadIndex = index
                return
            }
        }

        if let activeIndex = creationThreads.firstIndex(where: { !$0.isArchived }) {
            selectedCreationThreadID = creationThreads[activeIndex].id
            selectedCreationThreadIndex = activeIndex
            return
        }

        selectedCreationThreadID = nil
        selectedCreationThreadIndex = nil
    }

    private static func isCreationThreadOrderedBefore(
        _ lhs: CreationThreadSession,
        _ rhs: CreationThreadSession
    ) -> Bool {
        if lhs.isArchived != rhs.isArchived {
            return !lhs.isArchived
        }
        return lhs.lastUpdated > rhs.lastUpdated
    }
}
