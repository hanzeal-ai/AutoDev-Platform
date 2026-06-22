import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var viewModel: ShellViewModel

    init(viewModel: ShellViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        Group {
            if viewModel.state.daemonStatus == "Unknown" || !viewModel.state.isAuthenticated {
                pageBody
            } else {
                HStack(spacing: 0) {
                    AppSidebar(viewModel: viewModel)
                    Divider()

                    VStack(spacing: 0) {
                        AppHeader(viewModel: viewModel)
                        Divider()
                        pageBody
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .windowBackgroundColor))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(viewModel.state.appearanceMode.colorScheme)
        .task {
            await viewModel.loadIfNeeded()
        }
        .sheet(
            isPresented: Binding(
                get: { viewModel.state.isSettingsPresented },
                set: { viewModel.setSettingsPresented($0) }
            )
        ) {
            SettingsSheetView(viewModel: viewModel)
        }
        .sheet(
            isPresented: Binding(
                get: { viewModel.state.renameThreadTargetID != nil },
                set: { if !$0 { viewModel.dismissRenameCreationThread() } }
            )
        ) {
            RenameThreadSheetView(viewModel: viewModel)
        }
        .fileImporter(
            isPresented: Binding(
                get: { viewModel.state.isMaterialImporterPresented },
                set: { viewModel.setMaterialImporterPresented($0) }
            ),
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case let .success(urls):
                viewModel.addCreationMaterials(urls: urls)
            case let .failure(error):
                viewModel.handleCreationMaterialImportFailure(error)
            }
        }
    }

    @ViewBuilder
    private var pageBody: some View {
        if viewModel.state.daemonStatus == "Unknown" {
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.regular)
                Text("正在连接系统…")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("正在连接系统")
        } else if !viewModel.state.isAuthenticated {
            LoginPage(viewModel: viewModel)
        } else if viewModel.state.route.isProjectCreation {
            ProjectCreationPage(viewModel: viewModel)
                .padding(20)
        } else {
            ScrollView {
                switch viewModel.state.route {
                case .overview:
                    OverviewPage(viewModel: viewModel)
                case .projectLibrary:
                    ProjectLibraryPage(viewModel: viewModel)
                case .projectCreation:
                    EmptyView()
                case .projectDetail:
                    ProjectDetailPage(viewModel: viewModel)
                }
            }
            .padding(20)
        }
    }

}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(viewModel: .preview())
    }
}
#endif
