import SwiftUI

struct ProjectCurrentAgentSection: View {
    let snapshot: DeliveryWorkflowSnapshot?
    let detail: DeliveryExecutionDetail?
    let projectName: String
    @State private var now = Date()

    private let ticker = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        DashboardCard(title: "当前 Agent 执行") {
            VStack(alignment: .leading, spacing: 14) {
                header
                Divider()
                content
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .onReceive(ticker) { now = $0 }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(agentTitle)
                    .font(.subheadline.weight(.semibold))
                Text(projectName.isEmpty ? "当前项目" : projectName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            HStack(spacing: 6) {
                Circle()
                    .fill(activityColor)
                    .frame(width: 8, height: 8)
                Text(WorkflowActivityPresentation.label(for: activity))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(activityColor)
            }
            .help(activityDetail)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let snapshot {
            primaryContent(for: snapshot)
            issueReasonList
        } else {
            AgentNoticeLine(systemImage: "clock", title: "正在读取状态", detail: "等待 Workflow 状态返回。")
        }
    }

    @ViewBuilder
    private func primaryContent(for snapshot: DeliveryWorkflowSnapshot) -> some View {
        if snapshot.status == .failed, let error = snapshot.error, !error.isEmpty {
            AgentNoticeLine(systemImage: "exclamationmark.triangle.fill", title: "执行失败", detail: error)
        } else if snapshot.status == .blocked {
            AgentNoticeLine(systemImage: "pause.circle.fill", title: "流程阻塞", detail: latestDetail(fallback: "等待人工确认或补充处理。"))
        } else if activity == .waitingFirstToken || activity == .idleSuspected {
            AgentNoticeLine(systemImage: activity == .idleSuspected ? "exclamationmark.circle.fill" : "hourglass", title: WorkflowActivityPresentation.label(for: activity), detail: activityDetail)
            executionEvents
        } else if snapshot.currentStep == "coding", !fileNames.isEmpty {
            liveActionSummary
            fileSummary
            executionEvents
        } else {
            liveActionSummary
            stageSummary
            executionEvents
            stepList
        }
    }

    private var fileSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("已创建/更改 \(fileNames.count) 个文件")
                .font(.subheadline.weight(.semibold))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(fileNames, id: \.self) { name in
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                        Text(name)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
        }
    }

    @ViewBuilder
    private var stageSummary: some View {
        if let detail, !detail.objective.isEmpty {
            AgentNoticeLine(systemImage: "text.alignleft", title: "阶段摘要", detail: detail.objective)
        } else {
            AgentNoticeLine(systemImage: "sparkles", title: "执行状态", detail: latestDetail(fallback: "等待当前 Agent 输出。"))
        }
    }

    @ViewBuilder
    private var liveActionSummary: some View {
        if snapshot?.status == .running, let detail = currentActionDetail {
            AgentNoticeLine(systemImage: "sparkles", title: "当前动作", detail: detail)
        }
    }

    @ViewBuilder
    private var executionEvents: some View {
        let events = currentEvents
        if !events.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("执行过程")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                ForEach(events) { event in
                    AgentTimelineRow(event: event)
                }
            }
        }
    }

    @ViewBuilder
    private var stepList: some View {
        let steps = detail?.stepProgress ?? []
        if !steps.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("当前步骤")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                ForEach(steps.prefix(8)) { step in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(step.status == .completed ? Color.green : Color.accentColor)
                            .frame(width: 7, height: 7)
                        Text(step.title)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var issueReasonList: some View {
        let reasons = issueReasons
        if !reasons.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("异常原因")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                ForEach(reasons) { reason in
                    AgentNoticeLine(
                        systemImage: reason.status == .failed ? "exclamationmark.triangle.fill" : "pause.circle.fill",
                        title: "\(stageTitle(for: reason.stage)) · \(statusLabel(for: reason.status))",
                        detail: reason.detail
                    )
                }
            }
        }
    }

    private var agentTitle: String {
        "\(stageTitle(for: snapshot?.currentStep ?? "not_started")) Agent"
    }

    private var activity: DeliveryWorkflowActivityState {
        WorkflowActivityPresentation.activity(snapshot: snapshot, detail: detail, now: now)
    }

    private var activityColor: Color {
        WorkflowActivityPresentation.color(for: activity)
    }

    private var activityDetail: String {
        WorkflowActivityPresentation.detail(for: activity, snapshot: snapshot, detail: detail, now: now)
    }

    private var fileNames: [String] {
        let unitNames = (detail?.workUnits ?? []).map(\.title).filter { !$0.isEmpty }
        if !unitNames.isEmpty {
            return Array(unitNames.prefix(12))
        }
        let stepNames = (detail?.stepProgress ?? []).map(\.title).filter { !$0.isEmpty }
        return Array(stepNames.prefix(12))
    }

    private var currentEvents: [DeliveryWorkflowEventItem] {
        guard let snapshot else { return [] }
        let latest = snapshot.events
            .filter { $0.stage == snapshot.currentStep && $0.type == "log" }
            .sorted { $0.sequence > $1.sequence }
            .prefix(5)
        return Array(latest.reversed())
    }

    private var issueReasons: [WorkflowIssueReason] {
        guard let snapshot else { return [] }
        var seen = Set<String>()
        return snapshot.events
            .filter { $0.status == .failed || $0.status == .blocked }
            .sorted { $0.sequence < $1.sequence }
            .compactMap { event in
                let detail = event.detail.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !detail.isEmpty else { return nil }
                let key = "\(event.stage)|\(event.status.rawValue)|\(detail)"
                guard seen.insert(key).inserted else { return nil }
                return WorkflowIssueReason(stage: event.stage, status: event.status, detail: detail)
            }
    }

    private func latestDetail(fallback: String) -> String {
        currentEvents.last?.detail ?? fallback
    }

    private var currentActionDetail: String? {
        guard let detail = currentEvents.last?.detail.trimmingCharacters(in: .whitespacesAndNewlines),
              !detail.isEmpty
        else { return nil }
        return detail
    }

    private func stageTitle(for stage: String) -> String {
        ProjectWorkflowStatusPresentation.title(for: stage)
    }

    private func statusLabel(for status: DeliveryWorkflowNodeStatus) -> String {
        ProjectWorkflowStatusPresentation.label(for: status)
    }
}

private struct WorkflowIssueReason: Identifiable {
    let stage: String
    let status: DeliveryWorkflowNodeStatus
    let detail: String

    var id: String {
        "\(stage)-\(status.rawValue)-\(detail)"
    }
}

private struct AgentNoticeLine: View {
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: systemImage)
                .foregroundColor(.accentColor)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct AgentTimelineRow: View {
    let event: DeliveryWorkflowEventItem

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(ProjectWorkflowStatusPresentation.color(for: event.status))
                .frame(width: 7, height: 7)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 2) {
                if let timeLabel {
                    Text(timeLabel)
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.secondary.opacity(0.75))
                }
                Text(event.detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var timeLabel: String? {
        guard let createdAtMS = event.createdAtMS else { return nil }
        return Self.timeFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(createdAtMS) / 1000))
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}
