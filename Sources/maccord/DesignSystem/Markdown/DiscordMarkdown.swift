import SwiftUI
import MaccordCore

/// Lookup context used to resolve mentions while rendering markdown.
struct MarkdownContext: Sendable {
    var users: [Snowflake: String] = [:]
    var channels: [Snowflake: String] = [:]
    var roles: [Snowflake: Role] = [:]
    var currentUserID: Snowflake?
    /// Base point size for the body text these runs belong to.
    var baseSize: CGFloat = 15

    static let empty = MarkdownContext()
}

/// A pragmatic Discord-flavored markdown → AttributedString renderer.
///
/// Supports: `**bold**`, `*italic*` / `_italic_`, `__underline__`, `~~strike~~`,
/// `||spoiler||`, `` `inline code` ``, mentions (`<@id>`, `<@!id>`, `<#id>`,
/// `<@&id>`, `@everyone`, `@here`), custom emoji (`<:name:id>`), timestamps
/// (`<t:unix:style>`) and auto-linked URLs. Block elements (fenced code blocks,
/// headers, blockquotes) are split out by `MessageContentView` before this runs.
enum DiscordMarkdown {

    struct InlineStyle {
        var bold = false
        var italic = false
        var underline = false
        var strike = false
        var spoiler = false
        var code = false
    }

    static func attributed(_ content: String, context: MarkdownContext) -> AttributedString {
        let (text, fragments) = tokenize(content, context: context)
        var index = 0
        return render(Substring(text), style: InlineStyle(), context: context,
                      fragments: fragments, fragmentIndex: &index)
    }

    // MARK: Token extraction (mentions / emoji / timestamps / links)

    private static let mentionRegex = try! NSRegularExpression(pattern: "<@!?(\\d+)>")
    private static let channelRegex = try! NSRegularExpression(pattern: "<#(\\d+)>")
    private static let roleRegex = try! NSRegularExpression(pattern: "<@&(\\d+)>")
    private static let emojiRegex = try! NSRegularExpression(pattern: "<(a)?:(\\w+):(\\d+)>")
    private static let timestampRegex = try! NSRegularExpression(pattern: "<t:(\\d+)(?::([tTdDfFR]))?>")
    private static let urlRegex = try! NSRegularExpression(pattern: "https?://[^\\s<>\\)]+")
    private static let everyoneRegex = try! NSRegularExpression(pattern: "@(everyone|here)")
    private static let maskedLinkRegex = try! NSRegularExpression(pattern: "\\[([^\\]]+)\\]\\((https?://[^)\\s]+)\\)")

    private static let placeholder = "\u{FFFC}"

    /// Replace special tokens with an object-replacement char, returning the
    /// styled fragments in order of appearance.
    private static func tokenize(_ content: String, context: MarkdownContext) -> (String, [AttributedString]) {
        let ns = content as NSString
        var matches: [(NSRange, AttributedString)] = []

        func collect(_ regex: NSRegularExpression, _ make: (NSTextCheckingResult, NSString) -> AttributedString?) {
            for m in regex.matches(in: content, range: NSRange(location: 0, length: ns.length)) {
                if let frag = make(m, ns) { matches.append((m.range, frag)) }
            }
        }

        collect(mentionRegex) { m, ns in
            let id = Snowflake(string: ns.substring(with: m.range(at: 1))) ?? Snowflake(0)
            let name = context.users[id] ?? "user"
            return mentionFragment("@\(name)", isSelf: id == context.currentUserID)
        }
        collect(channelRegex) { m, ns in
            let id = Snowflake(string: ns.substring(with: m.range(at: 1))) ?? Snowflake(0)
            let name = context.channels[id] ?? "channel"
            return mentionFragment("#\(name)", isSelf: false)
        }
        collect(roleRegex) { m, ns in
            let id = Snowflake(string: ns.substring(with: m.range(at: 1))) ?? Snowflake(0)
            let role = context.roles[id]
            let color = role.flatMap { Color(discordColor: $0.color) } ?? DiscordColor.blurple
            return mentionFragment("@\(role?.name ?? "role")", isSelf: false, color: color)
        }
        collect(emojiRegex) { m, ns in
            let name = ns.substring(with: m.range(at: 2))
            var frag = AttributedString(":\(name):")
            frag.foregroundColor = DiscordColor.textNormal
            return frag
        }
        collect(timestampRegex) { m, ns in
            let unix = TimeInterval(ns.substring(with: m.range(at: 1))) ?? 0
            let style = m.range(at: 2).location != NSNotFound ? ns.substring(with: m.range(at: 2)) : "f"
            var frag = AttributedString(formatTimestamp(unix, style: style))
            frag.foregroundColor = DiscordColor.textNormal
            frag.backgroundColor = DiscordColor.surfaceHigher.opacity(0.5)
            return frag
        }
        collect(everyoneRegex) { m, ns in
            mentionFragment(ns.substring(with: m.range), isSelf: true)
        }
        // Masked links [label](url) — collected before bare URLs so the inner URL
        // (which sits inside the kept range) is dropped by overlap resolution.
        collect(maskedLinkRegex) { m, ns in
            let label = ns.substring(with: m.range(at: 1))
            let urlStr = ns.substring(with: m.range(at: 2))
            var frag = AttributedString(label)
            frag.foregroundColor = DiscordColor.linkBlue
            if let url = URL(string: urlStr) { frag.link = url }
            return frag
        }
        collect(urlRegex) { m, ns in
            let urlStr = ns.substring(with: m.range)
            var frag = AttributedString(urlStr)
            frag.foregroundColor = DiscordColor.linkBlue
            if let url = URL(string: urlStr) { frag.link = url }
            return frag
        }

        guard !matches.isEmpty else { return (content, []) }
        // Resolve overlaps: keep earliest, drop any that overlap a kept range.
        matches.sort { $0.0.location < $1.0.location }
        var kept: [(NSRange, AttributedString)] = []
        var cursor = 0
        for (range, frag) in matches where range.location >= cursor {
            kept.append((range, frag))
            cursor = range.location + range.length
        }

        var result = ""
        var fragments: [AttributedString] = []
        var last = 0
        for (range, frag) in kept {
            result += ns.substring(with: NSRange(location: last, length: range.location - last))
            result += placeholder
            fragments.append(frag)
            last = range.location + range.length
        }
        result += ns.substring(with: NSRange(location: last, length: ns.length - last))
        return (result, fragments)
    }

    private static func mentionFragment(_ text: String, isSelf: Bool, color: Color = DiscordColor.blurple) -> AttributedString {
        var frag = AttributedString(text)
        frag.foregroundColor = isSelf ? Color(hex: 0xC9CDFB) : color
        frag.backgroundColor = DiscordColor.blurple.opacity(isSelf ? 0.30 : 0.15)
        frag.font = .custom(DiscordFont.postScriptName(.medium), size: 16)
        return frag
    }

    // MARK: Emphasis parser (recursive, delimiter based)

    private struct Delim { let token: String; let apply: @Sendable (inout InlineStyle) -> Void }

    private static let delimiters: [Delim] = [
        Delim(token: "**") { $0.bold = true },
        Delim(token: "__") { $0.underline = true },
        Delim(token: "~~") { $0.strike = true },
        Delim(token: "||") { $0.spoiler = true },
        Delim(token: "*")  { $0.italic = true },
        Delim(token: "_")  { $0.italic = true },
    ]

    private static func render(_ s: Substring, style: InlineStyle, context: MarkdownContext,
                               fragments: [AttributedString], fragmentIndex: inout Int) -> AttributedString {
        var out = AttributedString()
        var i = s.startIndex
        var plainStart = i

        func flushPlain(upTo end: Substring.Index) {
            guard plainStart < end else { return }
            appendPlain(s[plainStart..<end], style: style, into: &out,
                        fragments: fragments, fragmentIndex: &fragmentIndex)
        }

        while i < s.endIndex {
            let c = s[i]
            // Inline code — highest priority, no nested formatting.
            if c == "`" {
                if let (inner, after) = scanCode(s, from: i) {
                    flushPlain(upTo: i)
                    var codeStyle = style; codeStyle.code = true
                    appendPlain(inner, style: codeStyle, into: &out,
                                fragments: fragments, fragmentIndex: &fragmentIndex)
                    i = after; plainStart = i; continue
                }
            }
            // Emphasis delimiters.
            if let d = delimiters.first(where: { s[i...].hasPrefix($0.token) }) {
                let openEnd = s.index(i, offsetBy: d.token.count)
                if let closeStart = findClosing(s, token: d.token, from: openEnd) {
                    flushPlain(upTo: i)
                    var inner = style
                    d.apply(&inner)
                    out += render(s[openEnd..<closeStart], style: inner, context: context,
                                  fragments: fragments, fragmentIndex: &fragmentIndex)
                    i = s.index(closeStart, offsetBy: d.token.count)
                    plainStart = i; continue
                }
            }
            i = s.index(after: i)
        }
        flushPlain(upTo: s.endIndex)
        return out
    }

    private static func scanCode(_ s: Substring, from start: Substring.Index) -> (Substring, Substring.Index)? {
        // count opening backticks (1 or more)
        var ticks = 0
        var i = start
        while i < s.endIndex, s[i] == "`" { ticks += 1; i = s.index(after: i) }
        let fence = String(repeating: "`", count: ticks)
        let contentStart = i
        guard let closeRange = s[contentStart...].range(of: fence) else { return nil }
        let inner = s[contentStart..<closeRange.lowerBound]
        return (inner, closeRange.upperBound)
    }

    private static func findClosing(_ s: Substring, token: String, from start: Substring.Index) -> Substring.Index? {
        guard start < s.endIndex else { return nil }
        var search = start
        while let r = s[search...].range(of: token) {
            // Don't match an empty span (e.g. "****").
            if r.lowerBound > start { return r.lowerBound }
            search = r.upperBound
            if search >= s.endIndex { break }
        }
        return nil
    }

    private static func appendPlain(_ text: Substring, style: InlineStyle, into out: inout AttributedString,
                                    fragments: [AttributedString], fragmentIndex: inout Int) {
        for ch in text {
            if String(ch) == placeholder {
                if fragmentIndex < fragments.count {
                    var frag = fragments[fragmentIndex]
                    fragmentIndex += 1
                    // Inherit emphasis font weight/traits over the fragment.
                    if style.bold || style.italic {
                        frag.font = font(for: style)
                    }
                    out += frag
                }
            } else {
                var run = AttributedString(String(ch))
                styleRun(&run, style: style)
                out += run
            }
        }
    }

    private static func styleRun(_ run: inout AttributedString, style: InlineStyle) {
        run.font = font(for: style)
        if style.code {
            run.foregroundColor = DiscordColor.textNormal
            run.backgroundColor = DiscordColor.codeBackground
        } else if style.spoiler {
            run.foregroundColor = DiscordColor.spoiler
            run.backgroundColor = DiscordColor.spoiler
        } else {
            run.foregroundColor = DiscordColor.textNormal
        }
        if style.underline { run.underlineStyle = .single }
        if style.strike { run.strikethroughStyle = .single }
    }

    private static func font(for style: InlineStyle) -> Font {
        if style.code { return .system(size: 15, design: .monospaced) }
        var f = Font.custom(DiscordFont.postScriptName(style.bold ? .bold : .regular), size: 16)
        if style.italic { f = f.italic() }
        return f
    }

    // MARK: Timestamp formatting

    private static func formatTimestamp(_ unix: TimeInterval, style: String) -> String {
        let date = Date(timeIntervalSince1970: unix)
        let f = DateFormatter()
        switch style {
        case "t": f.dateFormat = "h:mm a"
        case "T": f.dateFormat = "h:mm:ss a"
        case "d": f.dateFormat = "MM/dd/yyyy"
        case "D": f.dateFormat = "MMMM d, yyyy"
        case "F": f.dateFormat = "EEEE, MMMM d, yyyy h:mm a"
        case "R": return relative(date)
        default:  f.dateFormat = "MMMM d, yyyy h:mm a"
        }
        return f.string(from: date)
    }

    private static func relative(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f.localizedString(for: date, relativeTo: Date())
    }
}
