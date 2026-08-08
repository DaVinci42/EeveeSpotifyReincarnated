import Orion
import UIKit

enum CleanShareLinks {
    private static let spotifyShareURLPattern = #"https?://(?:[a-z0-9-]+\.)*open\.spotify\.com/[^\s"<>]+"#
    private static let spotifyShareURLRegex = try! NSRegularExpression(
        pattern: spotifyShareURLPattern,
        options: [.caseInsensitive]
    )

    /// Returns a copy of the URL with Spotify's `si` tracking parameter
    /// (and any `utm_*` marketing parameters) removed.
    static func cleanedURL(from url: URL) -> URL {
        guard UserDefaults.cleanShareLinks,
              let host = url.host?.lowercased(),
              host == "open.spotify.com" || host.hasSuffix(".open.spotify.com"),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.percentEncodedQueryItems, !items.isEmpty
        else {
            return url
        }

        // percentEncodedQueryItems preserves the original query encoding
        // (e.g. `context=spotify%3Aalbum%3A...`) instead of re-encoding it.
        let cleanedItems = items.filter { item in
            let name = item.name.lowercased()
            return name != "si" && !name.hasPrefix("utm_")
        }

        guard cleanedItems.count != items.count else { return url }

        components.percentEncodedQueryItems = cleanedItems.isEmpty ? nil : cleanedItems
        return components.url ?? url
    }

    /// Returns a copy of the string with any Spotify share links cleaned.
    static func cleanedString(from string: String) -> String {
        guard UserDefaults.cleanShareLinks else { return string }

        let nsString = string as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        var replacements: [(NSRange, String)] = []

        for match in spotifyShareURLRegex.matches(in: string, options: [], range: fullRange) {
            let urlString = nsString.substring(with: match.range)
            guard let url = URL(string: urlString) else { continue }

            let cleanedURLString = cleanedURL(from: url).absoluteString
            if cleanedURLString != urlString {
                replacements.append((match.range, cleanedURLString))
            }
        }

        guard !replacements.isEmpty else { return string }

        var result = string
        for (range, replacement) in replacements.reversed() {
            result = (result as NSString).replacingCharacters(in: range, with: replacement)
        }
        return result
    }

    static func cleanedActivityItem(_ item: Any) -> Any {
        if let url = item as? URL {
            return cleanedURL(from: url)
        }
        if let string = item as? String {
            return cleanedString(from: string)
        }
        return item
    }
}

/// Cleans Spotify share links written to the pasteboard ("Copy link" and the share sheet's Copy action).
///
/// Hooks both the typed setters and the lower-level primitives (`setValue:forPasteboardType:` /
/// `setData:forPasteboardType:`) since `UIPasteboard.general` may be a private subclass and the
/// typed setters are typically funneled through these primitives anyway.
class UIPasteboardCleanShareLinksHook: ClassHook<UIPasteboard> {
    func setURL(_ url: URL?) {
        orig.setURL(url.map { CleanShareLinks.cleanedURL(from: $0) })
    }

    func setURLs(_ urls: [URL]?) {
        orig.setURLs(urls?.map { CleanShareLinks.cleanedURL(from: $0) })
    }

    func setString(_ string: String?) {
        orig.setString(string.map { CleanShareLinks.cleanedString(from: $0) })
    }

    func setStrings(_ strings: [String]?) {
        orig.setStrings(strings?.map { CleanShareLinks.cleanedString(from: $0) })
    }

    func setItems(_ items: [[String: Any]], options: [UIPasteboard.OptionsKey: Any]) {
        orig.setItems(cleanPasteboardItems(items), options: options)
    }

    func addItems(_ items: [[String: Any]]) {
        orig.addItems(cleanPasteboardItems(items))
    }

    func setValue(_ value: Any?, forPasteboardType pasteboardType: String) {
        orig.setValue(value.map { cleanedValue($0) }, forPasteboardType: pasteboardType)
    }

    func setData(_ data: Data?, forPasteboardType pasteboardType: String) {
        orig.setData(cleanedData(data), forPasteboardType: pasteboardType)
    }

    private func cleanPasteboardItems(_ items: [[String: Any]]) -> [[String: Any]] {
        items.map { item in
            item.mapValues { value in cleanedValue(value) }
        }
    }

    private func cleanedValue(_ value: Any) -> Any {
        if let url = value as? URL {
            return CleanShareLinks.cleanedURL(from: url)
        }
        if let string = value as? String {
            return CleanShareLinks.cleanedString(from: string)
        }
        if let urls = value as? [URL] {
            return urls.map { CleanShareLinks.cleanedURL(from: $0) }
        }
        if let strings = value as? [String] {
            return strings.map { CleanShareLinks.cleanedString(from: $0) }
        }
        return value
    }

    private func cleanedData(_ data: Data?) -> Data? {
        // Covers plain-text pasteboard types (e.g. `public.utf8-plain-text`).
        // Archived `public.url` data is left untouched; URL objects written through
        // `setURL:`/`setValue:`/`setItems:` are already handled above.
        guard let data = data, let string = String(data: data, encoding: .utf8) else {
            return data
        }

        let cleaned = CleanShareLinks.cleanedString(from: string)
        guard cleaned != string else { return data }
        return cleaned.data(using: .utf8)
    }
}

/// Cleans Spotify share links passed to the system share sheet.
class UIActivityViewControllerCleanShareLinksHook: ClassHook<UIActivityViewController> {
    func initWithActivityItems(_ activityItems: [Any], applicationActivities: [UIActivity]?) -> Target {
        let cleanedItems = activityItems.map { CleanShareLinks.cleanedActivityItem($0) }
        return orig.initWithActivityItems(cleanedItems, applicationActivities: applicationActivities)
    }
}
