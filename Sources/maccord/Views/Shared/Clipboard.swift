import AppKit

/// Tiny wrapper over the general pasteboard for "Copy …" context-menu actions.
enum Clipboard {
    static func copy(_ string: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(string, forType: .string)
    }
}
