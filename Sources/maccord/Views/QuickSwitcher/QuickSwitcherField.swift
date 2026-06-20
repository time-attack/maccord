import SwiftUI
import AppKit

/// An NSTextField-backed search field for the quick switcher. SwiftUI's
/// `TextField` in an overlay is unreliable for first-responder focus and eats the
/// arrow keys we need for list navigation — this guarantees focus on appear,
/// live text updates, and ↑/↓/Return/Esc callbacks.
struct QuickSwitcherField: NSViewRepresentable {
    @Binding var text: String
    var onUp: () -> Void = {}
    var onDown: () -> Void = {}
    var onReturn: () -> Void = {}
    var onEscape: () -> Void = {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.delegate = context.coordinator
        field.placeholderString = "Where would you like to go?"
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 19)
        field.textColor = NSColor(DiscordColor.headerPrimary)
        field.lineBreakMode = .byTruncatingTail
        field.cell?.usesSingleLineMode = true
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        context.coordinator.parent = self
        if nsView.stringValue != text { nsView.stringValue = text }
        // Take first responder synchronously (we're already on the main actor here)
        // whenever the field isn't editing. The old code attempted this exactly once
        // and ignored failure, so if the sheet window wasn't key yet focus failed
        // forever and typing did nothing. The view nudges a few re-renders right
        // after open (see `focusTick`) so this retries until the window is key.
        if nsView.currentEditor() == nil {
            nsView.window?.makeFirstResponder(nsView)
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: QuickSwitcherField

        init(_ parent: QuickSwitcherField) { self.parent = parent }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue   // live updates → SwiftUI re-filters
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.moveUp(_:)):       parent.onUp(); return true
            case #selector(NSResponder.moveDown(_:)):     parent.onDown(); return true
            case #selector(NSResponder.insertNewline(_:)): parent.onReturn(); return true
            case #selector(NSResponder.cancelOperation(_:)): parent.onEscape(); return true
            default: return false
            }
        }
    }
}
