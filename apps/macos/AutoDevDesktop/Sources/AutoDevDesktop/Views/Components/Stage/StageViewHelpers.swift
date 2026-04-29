import SwiftUI
import AppKit

/// Extract file name from a full path.
func fileNameFromPath(_ path: String) -> String {
    (path as NSString).lastPathComponent
}

/// ViewModifier that shows a pointing-hand cursor on hover.
struct HandCursorOnHover: ViewModifier {
    func body(content: Content) -> some View {
        content.onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

/// ViewModifier that shows the not-allowed cursor on hover.
struct DisabledCursorOnHover: ViewModifier {
    func body(content: Content) -> some View {
        content.onHover { hovering in
            if hovering {
                NSCursor.operationNotAllowed.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

extension View {
    func handCursorOnHover() -> some View {
        modifier(HandCursorOnHover())
    }

    func disabledCursorOnHover() -> some View {
        modifier(DisabledCursorOnHover())
    }
}
