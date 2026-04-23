import Foundation

enum StageAutomationMode: String, CaseIterable, Identifiable {
    case fullAuto = "全自动"
    case selective = "选择性确认"
    case allManual = "全部人工确认"

    var id: String { rawValue }
}

struct StageAutomationConfig: Equatable {
    var mode: StageAutomationMode
    var manualConfirmStages: Set<DeliveryLifecycleStage>
    var manualSubSteps: Bool

    static let defaultConfig = StageAutomationConfig(
        mode: .fullAuto,
        manualConfirmStages: [],
        manualSubSteps: false
    )

    func stageNeedsConfirmation(_ stage: DeliveryLifecycleStage) -> Bool {
        switch mode {
        case .fullAuto:
            return false
        case .allManual:
            return true
        case .selective:
            return manualConfirmStages.contains(stage)
        }
    }

    func shouldAutoTriggerAI(for stage: DeliveryLifecycleStage) -> Bool {
        !stageNeedsConfirmation(stage)
    }

    // MARK: - UserDefaults Persistence

    private static let modeKey = "autodev.stageAutomation.mode"
    private static let manualStagesKey = "autodev.stageAutomation.manualStages"
    private static let manualSubStepsKey = "autodev.stageAutomation.manualSubSteps"

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(mode.rawValue, forKey: Self.modeKey)
        defaults.set(manualConfirmStages.map(\.rawValue), forKey: Self.manualStagesKey)
        defaults.set(manualSubSteps, forKey: Self.manualSubStepsKey)
    }

    static func load() -> StageAutomationConfig {
        let defaults = UserDefaults.standard
        let mode = defaults.string(forKey: modeKey)
            .flatMap(StageAutomationMode.init(rawValue:)) ?? .fullAuto
        let stageNames = defaults.stringArray(forKey: manualStagesKey) ?? []
        let stages = Set(stageNames.compactMap(DeliveryLifecycleStage.init(rawValue:)))
        let manualSub = defaults.bool(forKey: manualSubStepsKey)
        return StageAutomationConfig(mode: mode, manualConfirmStages: stages, manualSubSteps: manualSub)
    }
}
