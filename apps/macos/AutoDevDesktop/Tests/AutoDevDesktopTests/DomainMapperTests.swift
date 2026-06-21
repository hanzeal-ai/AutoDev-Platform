import XCTest
@testable import AutoDevDesktop

final class DomainMapperTests: XCTestCase {

    // MARK: - Lifecycle Stage Mapping

    func testLifecycleStageFromKnownStrings() {
        XCTAssertEqual(DomainMapper.lifecycleStage(from: "feasibility"), .feasibility)
        XCTAssertEqual(DomainMapper.lifecycleStage(from: "prd"), .prd)
        XCTAssertEqual(DomainMapper.lifecycleStage(from: "ui"), .ui)
        XCTAssertEqual(DomainMapper.lifecycleStage(from: "development"), .development)
        XCTAssertEqual(DomainMapper.lifecycleStage(from: "testing"), .testing)
        XCTAssertEqual(DomainMapper.lifecycleStage(from: "release"), .release)
        XCTAssertEqual(DomainMapper.lifecycleStage(from: "maintenance"), .maintenance)
    }

    func testLifecycleStageFromUnknownDefaultsToDevelopment() {
        XCTAssertEqual(DomainMapper.lifecycleStage(from: "unknown"), .development)
    }

    // MARK: - Project Status Mapping

    func testProjectStatusMapping() {
        XCTAssertEqual(DomainMapper.projectStatus(from: "running"), .running)
        XCTAssertEqual(DomainMapper.projectStatus(from: "queued"), .queued)
        XCTAssertEqual(DomainMapper.projectStatus(from: "awaiting_confirmation"), .awaitingConfirmation)
        XCTAssertEqual(DomainMapper.projectStatus(from: "blocked"), .blocked)
        XCTAssertEqual(DomainMapper.projectStatus(from: "failed"), .failed)
        XCTAssertEqual(DomainMapper.projectStatus(from: "completed"), .completed)
        XCTAssertEqual(DomainMapper.projectStatus(from: "archived"), .archived)
        XCTAssertEqual(DomainMapper.projectStatus(from: "unknown"), .running)
    }

    // MARK: - Project Risk Mapping

    func testProjectRiskMapping() {
        XCTAssertEqual(DomainMapper.projectRisk(from: "high"), .high)
        XCTAssertEqual(DomainMapper.projectRisk(from: "low"), .low)
        XCTAssertEqual(DomainMapper.projectRisk(from: "anything"), .medium)
    }

    // MARK: - Stage Key Mapping

    func testStageKeyRoundtrip() {
        for stage in DeliveryLifecycleStage.allCases {
            let key = DomainMapper.stageKey(stage)
            let back = DomainMapper.lifecycleStage(from: key)
            XCTAssertEqual(back, stage, "Round-trip failed for \(stage)")
        }
    }

    // MARK: - Project Mapping

    func testMapProjectWithValidUUID() {
        let dto = DaemonProject(
            id: "550e8400-e29b-41d4-a716-446655440000",
            title: "Test Project",
            currentPhase: "PRD",
            lifecycleStage: "prd",
            progress: 0.5,
            currentGoal: "Goal",
            nextAction: "Action",
            risk: "low",
            blockReason: nil,
            status: "running",
            owner: "AI",
            updatedAt: "刚刚"
        )
        let item = DomainMapper.mapProject(dto)
        XCTAssertNotNil(item)
        XCTAssertEqual(item?.title, "Test Project")
        XCTAssertEqual(item?.lifecycleStage, .prd)
        XCTAssertEqual(item?.risk, .low)
        XCTAssertEqual(item?.status, .running)
    }

    func testMapProjectWithInvalidUUIDReturnsNil() {
        let dto = DaemonProject(
            id: "not-a-uuid",
            title: "Test",
            currentPhase: "",
            lifecycleStage: "prd",
            progress: 0.0,
            currentGoal: "",
            nextAction: "",
            risk: "low",
            blockReason: nil,
            status: "running",
            owner: "",
            updatedAt: ""
        )
        let item = DomainMapper.mapProject(dto)
        XCTAssertNil(item)
    }

    func testMapWorkflowSnapshotKeepsCanonicalStageOrderAndEvents() {
        let status = DaemonProjectWorkflowStatus(
            workflowId: "wf-1",
            threadId: "thread-1",
            projectId: "project-1",
            projectName: "Demo",
            currentPhase: "coding_complete",
            currentStep: "coding",
            status: "running",
            awaitingUserInput: false,
            error: nil,
            phases: [
                "coding": DaemonWorkflowPhase(
                    status: "completed",
                    artifactId: "wf-1:coding",
                    name: "代码生成结果",
                    kind: "workflow-coding"
                ),
                "chat": DaemonWorkflowPhase(
                    status: "completed",
                    artifactId: "wf-1:chat",
                    name: "需求澄清结果",
                    kind: "workflow-chat"
                ),
                "code_review": DaemonWorkflowPhase(
                    status: "pending",
                    artifactId: nil,
                    name: "代码评审",
                    kind: "workflow-code-review"
                ),
            ],
            artifacts: [
                DaemonWorkflowArtifact(
                    artifactId: "wf-1:coding",
                    stage: "coding",
                    name: "代码生成结果",
                    kind: "workflow-coding",
                    status: "completed"
                )
            ]
        )
        let events = DaemonProjectWorkflowEvents(
            workflowId: "wf-1",
            threadId: "thread-1",
            projectId: "project-1",
            projectName: "Demo",
            currentPhase: "coding_complete",
            currentStep: "coding",
            status: "running",
            awaitingUserInput: false,
            error: nil,
            events: [
                DaemonWorkflowEvent(
                    id: "wf-1:log:0",
                    sequence: 9,
                    type: "log",
                    stage: "coding",
                    title: "过程事件",
                    detail: "tool:file_search",
                    status: "completed",
                    artifactId: nil
                )
            ]
        )

        let snapshot = DomainMapper.mapWorkflowSnapshot(status: status, events: events)

        XCTAssertEqual(snapshot.status, .running)
        XCTAssertEqual(snapshot.phases.map(\.stage), ["chat", "coding", "code_review"])
        XCTAssertEqual(snapshot.phases[1].artifactID, "wf-1:coding")
        XCTAssertEqual(snapshot.artifacts.first?.stage, "coding")
        XCTAssertEqual(snapshot.events.first?.detail, "tool:file_search")
    }

    // MARK: - Alert Level Mapping

    func testAlertLevelMapping() {
        XCTAssertEqual(DomainMapper.alertLevel(from: "critical"), .critical)
        XCTAssertEqual(DomainMapper.alertLevel(from: "info"), .info)
        XCTAssertEqual(DomainMapper.alertLevel(from: "unknown"), .warning)
    }

    // MARK: - Intervention Priority Mapping

    func testInterventionPriorityMapping() {
        XCTAssertEqual(DomainMapper.interventionPriority(from: "critical"), .critical)
        XCTAssertEqual(DomainMapper.interventionPriority(from: "low"), .low)
        XCTAssertEqual(DomainMapper.interventionPriority(from: "other"), .normal)
    }

    // MARK: - Material Status Mapping

    func testMaterialStatusMapping() {
        XCTAssertEqual(DomainMapper.materialStatus(from: "analyzed"), .analyzed)
        XCTAssertEqual(DomainMapper.materialStatus(from: "pending"), .queued)
    }

    // MARK: - Download Category Mapping

    func testDownloadCategoryMapping() {
        XCTAssertEqual(DomainMapper.downloadCategory(from: "raw_input"), .rawInput)
        XCTAssertEqual(DomainMapper.downloadCategory(from: "audit_archive"), .auditArchive)
        XCTAssertEqual(DomainMapper.downloadCategory(from: "other"), .stageSnapshot)
    }

    // MARK: - Download Availability Mapping

    func testDownloadAvailabilityMapping() {
        XCTAssertEqual(DomainMapper.downloadAvailability(from: "ready"), .ready)
        XCTAssertEqual(DomainMapper.downloadAvailability(from: "view_only"), .viewOnly)
        XCTAssertEqual(DomainMapper.downloadAvailability(from: "other"), .pending)
    }
}
