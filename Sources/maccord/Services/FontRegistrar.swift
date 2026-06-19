import Foundation
import CoreText
import MaccordCore

/// Registers any font files bundled under Resources/Fonts so `Font.custom(...)`
/// (e.g. "gg sans") resolves to them. No-op when the folder is empty — the UI
/// then falls back to the system font.
enum FontRegistrar {
    static func registerBundledFonts() {
        let exts = ["ttf", "otf"]
        var urls: [URL] = []
        for ext in exts {
            urls += Bundle.module.urls(forResourcesWithExtension: ext, subdirectory: "Fonts") ?? []
        }
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        MaccordLog.log("FontRegistrar registered \(urls.count) bundled font(s)")
    }
}
