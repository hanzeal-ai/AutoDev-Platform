import XCTest
@testable import AutoDevDesktop

final class ModelTests: XCTestCase {

    // MARK: - DeliveryLifecycleStage

    func testDeliveryLifecycleStageOrder() {
        let stages = DeliveryLifecycleStage.allCases
        for i in 0..<stages.count - 1 {
            XCTAssertLessThan(stages[i].order, stages[i + 1].order)
        }
    }

    func testDeliveryLifecycleStageAllCasesCount() {
        XCTAssertEqual(DeliveryLifecycleStage.allCases.count, 7)
    }

    // MARK: - ProjectStatus

    func testProjectStatusRawValues() {
        XCTAssertEqual(ProjectStatus.running.rawValue, "运行中")
        XCTAssertEqual(ProjectStatus.blocked.rawValue, "阻塞")
        XCTAssertEqual(ProjectStatus.completed.rawValue, "已完成")
        XCTAssertEqual(ProjectStatus.queued.rawValue, "排队中")
        XCTAssertEqual(ProjectStatus.awaitingConfirmation.rawValue, "待你确认")
        XCTAssertEqual(ProjectStatus.failed.rawValue, "失败")
        XCTAssertEqual(ProjectStatus.archived.rawValue, "已归档")
    }

    // MARK: - ProjectRisk

    func testProjectRiskRawValues() {
        XCTAssertEqual(ProjectRisk.low.rawValue, "低")
        XCTAssertEqual(ProjectRisk.medium.rawValue, "中")
        XCTAssertEqual(ProjectRisk.high.rawValue, "高")
    }

    // MARK: - StageAutomationConfig

    func testStageAutomationFullAuto() {
        let config = StageAutomationConfig(mode: .fullAuto, manualConfirmStages: [], manualSubSteps: false)
        XCTAssertFalse(config.stageNeedsConfirmation(.prd))
        XCTAssertFalse(config.stageNeedsConfirmation(.release))
        XCTAssertTrue(config.shouldAutoTriggerAI(for: .prd))
        XCTAssertTrue(config.shouldAutoTriggerAI(for: .release))
    }

    func testStageAutomationAllManual() {
        let config = StageAutomationConfig(mode: .allManual, manualConfirmStages: [], manualSubSteps: false)
        XCTAssertTrue(config.stageNeedsConfirmation(.prd))
        XCTAssertTrue(config.stageNeedsConfirmation(.development))
        XCTAssertFalse(config.shouldAutoTriggerAI(for: .prd))
        XCTAssertFalse(config.shouldAutoTriggerAI(for: .development))
    }

    func testStageAutomationSelective() {
        let config = StageAutomationConfig(mode: .selective, manualConfirmStages: [.prd, .release], manualSubSteps: false)
        XCTAssertTrue(config.stageNeedsConfirmation(.prd))
        XCTAssertTrue(config.stageNeedsConfirmation(.release))
        XCTAssertFalse(config.stageNeedsConfirmation(.development))
        XCTAssertFalse(config.stageNeedsConfirmation(.testing))
        XCTAssertTrue(config.shouldAutoTriggerAI(for: .development))
        XCTAssertFalse(config.shouldAutoTriggerAI(for: .prd))
    }

    func testStageAutomationDefaultConfig() {
        let config = StageAutomationConfig.defaultConfig
        XCTAssertEqual(config.mode, .fullAuto)
        XCTAssertTrue(config.manualConfirmStages.isEmpty)
        XCTAssertFalse(config.manualSubSteps)
    }

    // MARK: - AlertLevel

    func testAlertLevelRawValues() {
        XCTAssertEqual(AlertLevel.warning.rawValue, "告警")
        XCTAssertEqual(AlertLevel.critical.rawValue, "严重")
        XCTAssertEqual(AlertLevel.info.rawValue, "提示")
    }

    // MARK: - InterventionPriority

    func testInterventionPriorityRawValues() {
        XCTAssertEqual(InterventionPriority.critical.rawValue, "高")
        XCTAssertEqual(InterventionPriority.normal.rawValue, "中")
        XCTAssertEqual(InterventionPriority.low.rawValue, "低")
    }

    // MARK: - MaterialAnalysisStatus

    func testMaterialAnalysisStatusRawValues() {
        XCTAssertEqual(MaterialAnalysisStatus.queued.rawValue, "待分析")
        XCTAssertEqual(MaterialAnalysisStatus.analyzed.rawValue, "已分析")
    }
}
