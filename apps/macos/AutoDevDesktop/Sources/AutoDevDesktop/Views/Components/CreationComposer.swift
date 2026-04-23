import AppKit
import SwiftUI

struct CreationComposer: View {
    let threadID: UUID?
    let isSending: Bool
    @Binding var draft: String
    @Binding var insertionRequest: CreationInputInsertionRequest?
    let onSend: (UUID, String) -> Void

    private let minEditorHeight: CGFloat = 108
    private let maxEditorHeight: CGFloat = 188

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))

            CreationComposerTextView(
                text: $draft,
                insertionRequest: $insertionRequest,
                isEditable: threadID != nil && !isSending
            )
            .frame(minHeight: minEditorHeight, maxHeight: maxEditorHeight)

            if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("直接说你的目标、想法或约束，我会边聊边帮你收敛需求…")
                    .foregroundColor(.secondary)
                    .padding(.leading, 15)
                    .padding(.top, 12)
                    .padding(.trailing, 58)
                    .padding(.bottom, 30)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .allowsHitTesting(false)
            }

            Button(action: submit) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.9))
                    if isSending {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
                .frame(width: 42, height: 42)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundColor(.white)
            .padding(.trailing, 12)
            .padding(.bottom, 12)
            .disabled(
                draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    threadID == nil ||
                    isSending
            )
            .keyboardShortcut(.return, modifiers: [.command])
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.26), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: threadID) { _ in
            draft = ""
        }
    }

    private func submit() {
        guard let threadID = threadID else { return }
        guard !isSending else { return }
        let pending = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pending.isEmpty else { return }
        draft = ""
        onSend(threadID, pending)
    }
}

struct CreationComposerTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var insertionRequest: CreationInputInsertionRequest?
    let isEditable: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, insertionRequest: $insertionRequest)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return NSScrollView()
        }

        textView.isRichText = false
        textView.importsGraphics = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.drawsBackground = false
        textView.font = .preferredFont(forTextStyle: .body)
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.delegate = context.coordinator
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.contentInsets = NSEdgeInsets(top: 6, left: 10, bottom: 18, right: 54)

        textView.string = text
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }

        textView.isEditable = isEditable

        if textView.string != text {
            let selectedRange = textView.selectedRange()
            textView.string = text
            if selectedRange.location <= (textView.string as NSString).length {
                textView.setSelectedRange(selectedRange)
            }
        }

        if let request = insertionRequest, context.coordinator.lastHandledInsertionID != request.id {
            context.coordinator.handleInsertion(request)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var insertionRequest: Binding<CreationInputInsertionRequest?>
        weak var textView: NSTextView?
        var lastHandledInsertionID: UUID?

        init(
            text: Binding<String>,
            insertionRequest: Binding<CreationInputInsertionRequest?>
        ) {
            self.text = text
            self.insertionRequest = insertionRequest
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            text.wrappedValue = textView.string
        }

        func handleInsertion(_ request: CreationInputInsertionRequest) {
            guard let textView else { return }
            lastHandledInsertionID = request.id
            textView.window?.makeFirstResponder(textView)

            let selectedRange = textView.selectedRange()
            let updatedText = (textView.string as NSString).replacingCharacters(in: selectedRange, with: request.text)
            textView.string = updatedText
            let insertionLocation = selectedRange.location + (request.text as NSString).length
            textView.setSelectedRange(NSRange(location: insertionLocation, length: 0))
            text.wrappedValue = updatedText
            insertionRequest.wrappedValue = nil
        }
    }
}
