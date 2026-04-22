import SwiftUI

struct RenameThreadSheetView: View {
    @ObservedObject var viewModel: ShellViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AutoDevViewTheme.pageSpacing) {
            Text("重命名线程")
                .font(.title3.weight(.semibold))
            TextField(
                "线程名称",
                text: Binding(
                    get: { viewModel.state.renameThreadDraft },
                    set: { viewModel.updateRenameThreadDraft($0) }
                )
            )
            .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("取消") {
                    viewModel.dismissRenameCreationThread()
                }
                .buttonStyle(.bordered)
                Button("保存") {
                    viewModel.applyRenameCreationThread()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.state.renameThreadDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 360, minHeight: 160)
    }
}
