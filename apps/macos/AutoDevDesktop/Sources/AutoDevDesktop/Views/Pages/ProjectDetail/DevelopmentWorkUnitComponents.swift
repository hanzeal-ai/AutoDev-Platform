import SwiftUI

struct DevelopmentActiveUnitCard: View {
    @ObservedObject var viewModel: ShellViewModel
    let unit: DeliveryWorkUnitItem
    let projectName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(unit.title)
                        .font(.title3.weight(.semibold))
                        .lineLimit(2)
                    Text(projectName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int((unit.progress * 100).rounded()))%")
                        .font(.title3.weight(.semibold))
                    statusPill
                }
            }

            ProgressView(value: unit.progress)
                .progressViewStyle(.linear)

            DevelopmentSubTaskProgressList(items: DevelopmentWorkUnitPresenter.subTasks(for: unit))

            VStack(alignment: .leading, spacing: 6) {
                DevelopmentMetaLine(label: "Agent", value: unit.agentRole)
                if let currentOutput = unit.currentOutput, !currentOutput.isEmpty {
                    DevelopmentMetaLine(label: "当前产物", value: currentOutput)
                }
                DevelopmentMetaLine(label: "下一步", value: unit.nextStep)
            }

            if !unit.downloads.isEmpty {
                DevelopmentUnitDownloads(viewModel: viewModel, downloads: unit.downloads)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var statusPill: some View {
        Text(unit.status.rawValue)
            .font(.caption.weight(.semibold))
            .foregroundColor(unit.status.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(unit.status.color.opacity(0.12), in: Capsule())
    }
}

struct DevelopmentWorkUnitBoard: View {
    @ObservedObject var viewModel: ShellViewModel
    let units: [DeliveryWorkUnitItem]
    private let columns = [
        GridItem(.flexible(minimum: 220), spacing: AutoDevViewTheme.compactSpacing),
        GridItem(.flexible(minimum: 220), spacing: AutoDevViewTheme.compactSpacing),
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: AutoDevViewTheme.compactSpacing) {
            ForEach(units) { unit in
                DevelopmentWorkUnitRow(viewModel: viewModel, unit: unit)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }
}

private struct DevelopmentWorkUnitRow: View {
    @ObservedObject var viewModel: ShellViewModel
    let unit: DeliveryWorkUnitItem
    @State private var showsExecutionDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(unit.status.color)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
                VStack(alignment: .leading, spacing: 4) {
                    Text(unit.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                    Text(unit.agentRole)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int((unit.progress * 100).rounded()))%")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    Text(unit.status.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(unit.status.color)
                }
            }

            ProgressView(value: unit.progress)
                .progressViewStyle(.linear)

            VStack(alignment: .leading, spacing: 5) {
                DevelopmentMetaLine(label: "前置单元", value: unit.dependsOn.isEmpty ? "无" : unit.dependsOn.joined(separator: "、"))
                DevelopmentMetaLine(label: "下一步", value: unit.nextStep)
            }

            Button("查看执行") {
                showsExecutionDetail = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .sheet(isPresented: $showsExecutionDetail) {
            DevelopmentWorkUnitDetailSheet(viewModel: viewModel, unit: unit)
        }
    }
}

private struct DevelopmentWorkUnitDetailSheet: View {
    @ObservedObject var viewModel: ShellViewModel
    let unit: DeliveryWorkUnitItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(unit.title)
                        .font(.title3.weight(.semibold))
                    Text(unit.agentRole)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("关闭") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }

            ProgressView(value: unit.progress)
                .progressViewStyle(.linear)

            VStack(alignment: .leading, spacing: 6) {
                DevelopmentMetaLine(label: "状态", value: unit.status.rawValue)
                DevelopmentMetaLine(label: "前置单元", value: unit.dependsOn.isEmpty ? "无" : unit.dependsOn.joined(separator: "、"))
                if let currentOutput = unit.currentOutput, !currentOutput.isEmpty {
                    DevelopmentMetaLine(label: "当前产物", value: currentOutput)
                }
                DevelopmentMetaLine(label: "下一步", value: unit.nextStep)
            }

            DevelopmentSubTaskProgressList(items: DevelopmentWorkUnitPresenter.subTasks(for: unit))

            if !unit.downloads.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("产物下载")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    DevelopmentUnitDownloads(viewModel: viewModel, downloads: unit.downloads)
                }
            }
        }
        .padding(20)
        .frame(width: 560, alignment: .topLeading)
    }
}

private struct DevelopmentSubTaskProgressList: View {
    let items: [DeliverySubTaskItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("细分任务")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)

            ForEach(items) { item in
                HStack(spacing: 8) {
                    Circle()
                        .fill(item.status.color)
                        .frame(width: 6, height: 6)
                    Text(item.title)
                        .font(.caption)
                        .foregroundColor(.primary.opacity(0.86))
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text("\(Int((item.progress * 100).rounded()))%")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                ProgressView(value: item.progress)
                    .progressViewStyle(.linear)
                    .controlSize(.mini)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct DevelopmentUnitDownloads: View {
    @ObservedObject var viewModel: ShellViewModel
    let downloads: [StageDownloadItem]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(downloads) { item in
                switch item.availability {
                case .ready, .viewOnly:
                    if item.filePath?.isEmpty == false {
                        Button(item.title) {
                            viewModel.openStageDownload(item)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                case .pending:
                    EmptyView()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DevelopmentMetaLine: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
                .frame(width: 54, alignment: .leading)
            Text(value)
                .font(.caption)
                .foregroundColor(.primary.opacity(0.86))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
