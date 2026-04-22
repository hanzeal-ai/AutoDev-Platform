import SwiftUI

struct CreationThreadPanel: View {
    let threads: [CreationThreadSession]
    let selectedThreadID: UUID?
    let onTogglePanel: () -> Void
    let onCreateThread: () -> Void
    let onSelectThread: (UUID) -> Void
    let onBeginRenameThread: (UUID) -> Void
    let onArchiveThread: (UUID) -> Void
    let onDeleteThread: (UUID) -> Void

    var body: some View {
        DashboardCard(title: "立项线程") {
            VStack(alignment: .leading, spacing: AutoDevViewTheme.cardSpacing) {
                HStack {
                    Text("会话列表")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button(action: onTogglePanel) {
                        Image(systemName: "sidebar.left")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Button(action: onCreateThread) {
                    Label("新开线程", systemImage: "plus.message.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                ScrollView {
                    LazyVStack(spacing: AutoDevViewTheme.compactSpacing) {
                        ForEach(threads) { thread in
                            CreationThreadRowView(
                                thread: thread,
                                isSelected: selectedThreadID == thread.id,
                                onSelect: onSelectThread,
                                onRename: onBeginRenameThread,
                                onArchive: onArchiveThread,
                                onDelete: onDeleteThread
                            )
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}
