import SwiftUI
import AppKit

/// An NSTextView-backed message input. Unlike SwiftUI's `TextField(axis:.vertical)`
/// (which turns Return into a newline and never fires `onSubmit`), this gives the
/// real Discord behaviour: **Return sends**, **Shift+Return inserts a newline**,
/// and the field auto-grows with its content up to a cap.
struct ComposerTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var measuredHeight: CGFloat
    var placeholder: String
    var spellcheck: Bool = true
    var onSend: () -> Void
    var onChange: () -> Void
    var onPasteImage: (Data, String) -> Void = { _, _ in }

    private let minHeight: CGFloat = 22
    private let maxHeight: CGFloat = 200

    /// Sendable binding the coordinator can write back to off the delegate callback.
    var heightBinding: Binding<CGFloat> { $measuredHeight }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = PlaceholderTextView()
        textView.delegate = context.coordinator
        textView.string = text
        textView.placeholder = placeholder
        textView.font = .systemFont(ofSize: 15)
        textView.textColor = NSColor(DiscordColor.textNormal)
        textView.insertionPointColor = NSColor(DiscordColor.textNormal)
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isContinuousSpellCheckingEnabled = spellcheck
        textView.isAutomaticSpellingCorrectionEnabled = spellcheck
        textView.onPasteImage = onPasteImage
        textView.textContainerInset = NSSize(width: 0, height: 1)
        textView.textContainer?.lineFragmentPadding = 0
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        let scroll = NSScrollView()
        scroll.documentView = textView
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = false
        scroll.hasHorizontalScroller = false
        scroll.verticalScrollElasticity = .none
        context.coordinator.textView = textView
        context.coordinator.recalcHeight()
        return scroll
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? PlaceholderTextView else { return }
        if textView.string != text {
            textView.string = text
            context.coordinator.recalcHeight()
        }
        textView.placeholder = placeholder
        textView.textColor = NSColor(DiscordColor.textNormal)
        textView.isContinuousSpellCheckingEnabled = spellcheck
        textView.isAutomaticSpellingCorrectionEnabled = spellcheck
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        let parent: ComposerTextEditor
        weak var textView: PlaceholderTextView?

        init(_ parent: ComposerTextEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            parent.text = textView.string
            parent.onChange()
            recalcHeight()
        }

        /// Return → send (consume); Shift+Return → newline (pass through).
        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            if selector == #selector(NSResponder.insertNewline(_:)) {
                let shift = NSApp.currentEvent?.modifierFlags.contains(.shift) ?? false
                if shift {
                    textView.insertNewlineIgnoringFieldEditor(nil)
                    recalcHeight()
                    return true
                }
                parent.onSend()
                return true
            }
            return false
        }

        func recalcHeight() {
            guard let textView,
                  let layoutManager = textView.layoutManager,
                  let container = textView.textContainer else { return }
            layoutManager.ensureLayout(for: container)
            let used = layoutManager.usedRect(for: container).height
            let clamped = min(max(used + 2, parent.minHeight), parent.maxHeight)
            guard abs(clamped - parent.measuredHeight) > 0.5 else { return }
            // Capture only Sendable values (binding + value) so the deferred write
            // doesn't smuggle the non-Sendable coordinator across the boundary.
            let binding = parent.heightBinding
            DispatchQueue.main.async { binding.wrappedValue = clamped }
        }
    }
}

/// NSTextView that paints placeholder text when empty and wraps the selection in
/// markdown markers for Cmd+B/I/U (Discord's composer formatting shortcuts).
final class PlaceholderTextView: NSTextView {
    var placeholder: String = ""
    var onPasteImage: ((Data, String) -> Void)?

    /// Paste an image from the clipboard as an upload; otherwise paste text.
    override func paste(_ sender: Any?) {
        let pb = NSPasteboard.general
        if let images = pb.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let image = images.first,
           let tiff = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff),
           let png = bitmap.representation(using: .png, properties: [:]) {
            onPasteImage?(png, "pasted-image.png")
            return
        }
        super.paste(sender)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           let chars = event.charactersIgnoringModifiers {
            switch chars {
            case "b": wrapSelection(with: "**"); return true
            case "i": wrapSelection(with: "*"); return true
            case "u": wrapSelection(with: "__"); return true
            default: break
            }
        }
        return super.performKeyEquivalent(with: event)
    }

    /// Wrap the current selection (or insertion point) in `marker` on each side.
    private func wrapSelection(with marker: String) {
        let range = selectedRange()
        let selected = (string as NSString).substring(with: range)
        let replacement = marker + selected + marker
        guard shouldChangeText(in: range, replacementString: replacement) else { return }
        replaceCharacters(in: range, with: replacement)
        didChangeText()
        let markerLen = (marker as NSString).length
        if selected.isEmpty {
            setSelectedRange(NSRange(location: range.location + markerLen, length: 0))
        } else {
            setSelectedRange(NSRange(location: range.location + markerLen, length: (selected as NSString).length))
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty, !placeholder.isEmpty else { return }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font ?? .systemFont(ofSize: 15),
            .foregroundColor: NSColor(DiscordColor.channelDefault),
        ]
        let origin = NSPoint(x: textContainerInset.width, y: textContainerInset.height)
        placeholder.draw(at: origin, withAttributes: attrs)
    }
}
