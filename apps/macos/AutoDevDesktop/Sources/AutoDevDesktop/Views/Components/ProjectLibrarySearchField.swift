import SwiftUI

struct ProjectLibrarySearchField: View {
    let initialValue: String
    let onDebouncedChange: (String) -> Void

    @State private var draft: String
    @State private var syncTask: Task<Void, Never>?

    init(initialValue: String, onDebouncedChange: @escaping (String) -> Void) {
        self.initialValue = initialValue
        self.onDebouncedChange = onDebouncedChange
        _draft = State(initialValue: initialValue)
    }

    var body: some View {
        TextField("搜索项目", text: $draft)
            .textFieldStyle(.roundedBorder)
            .onChange(of: draft) { value in
                syncTask?.cancel()
                syncTask = Task {
                    try? await Task.sleep(nanoseconds: 180_000_000)
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        onDebouncedChange(value)
                    }
                }
            }
            .onChange(of: initialValue) { value in
                guard value != draft else { return }
                draft = value
            }
            .onDisappear {
                syncTask?.cancel()
            }
    }
}
