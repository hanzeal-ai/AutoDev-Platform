import SwiftUI

/// Lightweight Markdown renderer for Agent messages.
/// Supports inline Markdown such as **bold**, *italic*, `inline code`, links, and line breaks.
struct AgentMarkdownText: View {
    let text: String

    var body: some View {
        if let attributed = try? AttributedString(markdown: text, options: markdownOptions) {
            Text(attributed)
                .font(.subheadline)
                .lineSpacing(3)
                .textSelection(.enabled)
                .tint(.accentColor)
        } else {
            Text(text)
                .font(.subheadline)
                .lineSpacing(3)
                .textSelection(.enabled)
        }
    }

    private var markdownOptions: AttributedString.MarkdownParsingOptions {
        .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    }
}
