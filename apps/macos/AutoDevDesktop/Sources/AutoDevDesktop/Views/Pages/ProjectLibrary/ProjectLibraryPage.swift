import SwiftUI

struct ProjectLibraryPage: View {
    @ObservedObject var viewModel: ShellViewModel

    var body: some View {
        let visibleProjects = viewModel.state.projectLibraryProjects
        let counts = viewModel.state.projectLibraryCounts

        return VStack(alignment: .leading, spacing: AutoDevViewTheme.pageSpacing) {
            HStack {
                Text("项目库")
                    .font(.title3.weight(.semibold))
                Spacer()
                ProjectLibrarySearchField(
                    initialValue: viewModel.state.projectLibrarySearchQuery,
                    onDebouncedChange: { value in
                        viewModel.updateProjectLibrarySearchQuery(value)
                    }
                )
                .frame(width: 220)
                Button(action: { viewModel.openProjectCreation() }) {
                    Label("新建项目", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }

            HStack(spacing: AutoDevViewTheme.pageSpacing) {
                ForEach(ProjectLibraryFilter.allCases) { filter in
                    ProjectLibraryFilterCard(
                        filter: filter,
                        count: counts[filter, default: 0],
                        isSelected: viewModel.state.projectLibraryFilter == filter,
                        action: { viewModel.selectProjectLibraryFilter(filter) }
                    )
                }
            }

            DashboardCard(title: "项目列表") {
                if visibleProjects.isEmpty {
                    Text("暂无")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                } else {
                    LazyVStack(spacing: AutoDevViewTheme.compactSpacing) {
                        ForEach(visibleProjects) { project in
                            ProjectRowView(viewModel: viewModel, project: project, source: .projectLibrary)
                        }
                    }
                }
            }
        }
    }
}

private struct ProjectLibraryFilterCard: View {
    let filter: ProjectLibraryFilter
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(filter.rawValue)
                    .font(.caption)
                    .foregroundColor(isSelected ? .primary : .secondary)
                Text("\(count)")
                    .font(.headline.monospaced())
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                isSelected ? Color.accentColor.opacity(0.16) : Color(nsColor: .controlBackgroundColor),
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.45) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
