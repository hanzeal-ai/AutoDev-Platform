# Command and Event Catalog v0.1

## 1. Purpose

This catalog defines how bounded contexts coordinate without direct write coupling.

Rules:

- commands are intent
- events are facts
- commands target one owner context
- events are immutable once published
- consumers react asynchronously unless a synchronous result is explicitly required

## 2. Command Naming Convention

- `Create...`
- `Update...`
- `Approve...`
- `Reject...`
- `Plan...`
- `Run...`
- `Publish...`
- `Open...`
- `Resolve...`

Commands should be imperative. Events should be factual and past tense.

## 3. Requirement Context

### Commands

- `CreateRequirement`
- `StartRequirementClarification`
- `ResolveRequirementQuestion`
- `ConfirmRequirement`
- `ArchiveRequirement`

### Events

- `RequirementCreated`
- `RequirementClarificationStarted`
- `RequirementQuestionResolved`
- `RequirementConfirmed`
- `RequirementChanged`
- `RequirementArchived`

## 4. Product Spec Context

### Commands

- `CreatePRDFromRequirement`
- `UpdatePRD`
- `SubmitPRDForReview`
- `ApprovePRD`
- `RejectPRD`
- `SupersedePRD`

### Events

- `PRDCreated`
- `PRDUpdated`
- `PRDSubmittedForReview`
- `PRDApproved`
- `PRDRejected`
- `PRDSuperseded`
- `AcceptanceCriteriaDefined`

## 5. Design Context

### Commands

- `CreateDesignSpec`
- `AttachUIScreen`
- `UpdateInteractionFlow`
- `SubmitDesignForReview`
- `ApproveDesign`
- `RequestDesignChanges`

### Events

- `DesignSpecCreated`
- `UIScreenAttached`
- `InteractionFlowUpdated`
- `DesignSubmittedForReview`
- `DesignApproved`
- `DesignChangesRequested`
- `DesignSuperseded`

## 6. Engineering Context

### Commands

- `CreateADR`
- `ApproveADR`
- `PlanTasksFromPRD`
- `StartTask`
- `BlockTask`
- `CompleteTask`
- `CreateCodeChange`
- `RunCodeChange`
- `MarkCodeChangeReadyForReview`
- `MarkCodeChangeMerged`

### Events

- `ADRCreated`
- `ADRApproved`
- `TasksPlanned`
- `TaskStarted`
- `TaskBlocked`
- `TaskCompleted`
- `CodeChangeCreated`
- `CodeChangeExecutionStarted`
- `CodeChangeReadyForReview`
- `CodeChangeMerged`
- `CodeChangeFailed`

## 7. Testing Context

### Commands

- `DefineTestCase`
- `RunTestSuite`
- `EvaluateQualityGate`
- `OverrideQualityGate`

### Events

- `TestCaseDefined`
- `TestRunStarted`
- `TestRunCompleted`
- `QualityGateEvaluationStarted`
- `QualityGatePassed`
- `QualityGateFailed`
- `QualityGateOverridden`

## 8. Release Context

### Commands

- `CreateBuild`
- `CreateReleaseCandidate`
- `PublishRelease`
- `RollbackRelease`
- `CancelRelease`

### Events

- `BuildCreated`
- `BuildCompleted`
- `BuildFailed`
- `ReleaseCandidateCreated`
- `ReleasePublished`
- `ReleaseRolledBack`
- `ReleaseCancelled`

## 9. Operations Context

### Commands

- `OpenIncident`
- `AssignIncidentOwner`
- `MitigateIncident`
- `ResolveIncident`
- `CloseIncident`
- `CreatePostmortem`
- `CreateCorrectiveAction`

### Events

- `AlertReceived`
- `IncidentOpened`
- `IncidentOwnerAssigned`
- `IncidentMitigated`
- `IncidentResolved`
- `IncidentClosed`
- `PostmortemCreated`
- `CorrectiveActionCreated`
- `IncidentFeedbackCaptured`

## 10. Identity and Collaboration Context

### Commands

- `RequestApproval`
- `ApproveRequest`
- `RejectRequest`
- `AddComment`
- `SubscribeToArtifact`

### Events

- `ApprovalRequested`
- `ApprovalGranted`
- `ApprovalRejected`
- `CommentAdded`
- `SubscriptionCreated`

## 11. Integration Hub Context

### Commands

- `RegisterConnector`
- `IngestWebhook`
- `DispatchWebhook`
- `MapExternalEvent`
- `RetryOutboundDelivery`

### Events

- `ConnectorRegistered`
- `WebhookReceived`
- `WebhookMapped`
- `OutboundDeliveryQueued`
- `OutboundDeliverySucceeded`
- `OutboundDeliveryFailed`

## 12. Core Cross-Context Handoffs

| Upstream Event | Downstream Command | Purpose |
|---|---|---|
| `RequirementConfirmed` | `CreatePRDFromRequirement` | start product specification |
| `PRDApproved` | `CreateDesignSpec` | start UI/design work |
| `PRDApproved` | `PlanTasksFromPRD` | start engineering planning |
| `DesignApproved` | `CreateCodeChange` or `StartTask` | unblock implementation |
| `CodeChangeReadyForReview` | `RunTestSuite` | start verification |
| `QualityGatePassed` | `CreateReleaseCandidate` | allow release flow |
| `ReleasePublished` | `OpenIncident` or `SubscribeToArtifact` | enter operational monitoring |
| `IncidentFeedbackCaptured` | `CreateRequirement` | feed learning back into product flow |

## 13. Synchronous vs Asynchronous Rules

Use synchronous command handling for:

- direct UI edits of owned aggregates
- user-visible validation
- approval decisions

Use asynchronous event handling for:

- cross-context propagation
- heavy execution
- external integrations
- indexing
- notifications
- analytics

## 14. Idempotency and Reliability Rules

- every command should carry a `command_id`
- every event should carry an `event_id`
- every integration delivery should support retry with deduplication
- event consumers must be idempotent
- no event should assume in-order delivery from external systems
