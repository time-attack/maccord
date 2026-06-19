import Foundation

/// Lightweight append-only diagnostic log. Writes to `$MACCORD_LOG_FILE` (or
/// `/tmp/maccord.log`) so the GUI app's networking can be inspected after a run.
/// Never logs token values.
public enum MaccordLog {
    private static let path =
        ProcessInfo.processInfo.environment["MACCORD_LOG_FILE"] ?? "/tmp/maccord.log"
    private static let lock = NSLock()

    /// Temporarily always-on for diagnostics so a normal GUI launch writes the
    /// log to `/tmp/maccord.log`. (Gate behind the env vars again once stable.)
    public static let isEnabled = true

    public static func log(_ message: @autoclosure () -> String) {
        guard isEnabled else { return }
        let line = "\(Date().timeIntervalSince1970) \(message())\n"
        lock.lock(); defer { lock.unlock() }
        guard let data = line.data(using: .utf8) else { return }
        if let fh = FileHandle(forWritingAtPath: path) {
            defer { try? fh.close() }
            _ = try? fh.seekToEnd()
            try? fh.write(contentsOf: data)
        } else {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }
}
