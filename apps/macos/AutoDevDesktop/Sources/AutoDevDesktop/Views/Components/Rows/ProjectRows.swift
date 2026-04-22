import SwiftUI

struct ProjectRowView: View {
    @ObservedObject var viewModel: ShellViewModel
    let project: DeliveryProjectItem
    let source: ProjectDetailBackTarget

    var body: some View {
        Button {
            viewModel.openProjectDetail(projectID: project.id, from: source)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(project.status.color)
                    .frame(width: 6, height: 36)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(project.title)
                            .font(.subheadline.weight(.semibold))
                            .multilineTextAlignment(.leading)
                        LifecycleBadge(stage: project.lifecycleStage)
                    }
                    Text("\(project.currentPhase) · \(Int((project.progress * 100).rounded()))%")
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                    LifecycleTrack(current: project.lifecycleStage, compact: true)
                    Text(project.nextAction)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    if let blockReason = project.blockReason {
                        Text(blockReason)
                            .font(.caption)
                            .foregroundColor(.red)
                            .lineLimit(2)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(project.status.rawValue)
                        .font(.caption.weight(.medium))
                        .foregroundColor(project.status.color)
                    Text("风险 \(project.risk.rawValue)")
                        .font(.caption)
                        .foregroundColor(project.risk.color)
                    Text(project.updateTime)
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
