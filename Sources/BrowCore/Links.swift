import Foundation

/// Recognises web addresses worth saving: http(s) only, so no file:, javascript:
/// or mailto: links end up one click away.
public enum WebLink {
    public static func parse(_ text: String) -> URL? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { return nil }
        if text.contains(":") && !text.contains("://") {
            return nil   // javascript:, mailto: and the like
        }
        let candidate = text.contains("://") ? text : "https://" + text
        guard let url = URL(string: candidate),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty else { return nil }
        if !text.contains("://") {
            // A bare address needs a real-looking domain, not just any word.
            let labels = host.split(separator: ".")
            guard labels.count >= 2, let tld = labels.last, tld.count >= 2,
                  tld.allSatisfy(\.isLetter) else { return nil }
        }
        return url
    }
}

public struct SavedLink: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let url: URL
    public var pageTitle: String?
    public var customTitle: String?
    public var icon: Data?
    public let added: Date

    /// The user's name, else the page title, else the address without the scheme.
    public var displayTitle: String {
        customTitle ?? pageTitle ?? address
    }

    public var address: String {
        var text = (url.host ?? "") + url.path
        if text.hasSuffix("/") { text.removeLast() }
        return text
    }
}

/// Saved links, newest first.
public struct LinkStore: Codable, Equatable, Sendable {
    public private(set) var links: [SavedLink] = []

    public init() {}

    /// Adding a saved address again moves it to the top and keeps its name.
    @discardableResult
    public mutating func add(_ url: URL, now: Date = .now) -> UUID {
        let key = Self.key(url)
        if let index = links.firstIndex(where: { Self.key($0.url) == key }) {
            let existing = links.remove(at: index)
            links.insert(existing, at: 0)
            return existing.id
        }
        let link = SavedLink(id: UUID(), url: url, pageTitle: nil, customTitle: nil, icon: nil, added: now)
        links.insert(link, at: 0)
        return link.id
    }

    public mutating func remove(id: UUID) {
        links.removeAll { $0.id == id }
    }

    public mutating func removeAll() {
        links.removeAll()
    }

    /// An empty name brings back the page title.
    public mutating func rename(id: UUID, to name: String) {
        guard let index = links.firstIndex(where: { $0.id == id }) else { return }
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        links[index].customTitle = name.isEmpty ? nil : name
    }

    public mutating func setPageInfo(id: UUID, title: String?, icon: Data?) {
        guard let index = links.firstIndex(where: { $0.id == id }) else { return }
        if let title { links[index].pageTitle = title }
        if let icon { links[index].icon = icon }
    }

    public var linksNeedingPageInfo: [SavedLink] {
        links.filter { $0.pageTitle == nil }
    }

    private static func key(_ url: URL) -> String {
        var path = url.path
        while path.hasSuffix("/") { path.removeLast() }
        let query = url.query.map { "?" + $0 } ?? ""
        return (url.host ?? "").lowercased() + path + query
    }
}

/// Title and icon of a web page, read from its HTML.
public enum PageInfo {
    public static func title(fromHTML html: String) -> String? {
        let candidates = [
            firstMatch(#"<meta[^>]+property\s*=\s*["']og:title["'][^>]*content\s*=\s*["']([^"']*)["']"#, in: html),
            firstMatch(#"<meta[^>]+content\s*=\s*["']([^"']*)["'][^>]*property\s*=\s*["']og:title["']"#, in: html),
            firstMatch(#"<title[^>]*>(.*?)</title>"#, in: html),
        ]
        for candidate in candidates.compactMap({ $0 }) {
            let text = decodeEntities(candidate)
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            if !text.isEmpty { return text }
        }
        return nil
    }

    /// The page's declared icon, else /favicon.ico on its host.
    public static func iconURL(fromHTML html: String, page: URL) -> URL? {
        let tags = matches(#"<link\b[^>]*>"#, in: html)
        for tag in tags {
            guard let rel = firstMatch(#"rel\s*=\s*["']([^"']*)["']"#, in: tag)?.lowercased(),
                  rel.split(separator: " ").contains("icon"),
                  let href = firstMatch(#"href\s*=\s*["']([^"']*)["']"#, in: tag) else { continue }
            if let url = URL(string: decodeEntities(href), relativeTo: page)?.absoluteURL { return url }
        }
        return URL(string: "/favicon.ico", relativeTo: page)?.absoluteURL
    }

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }

    private static func matches(_ pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
            Range($0.range, in: text).map { String(text[$0]) }
        }
    }

    private static func decodeEntities(_ text: String) -> String {
        var result = text
        for (entity, value) in ["&quot;": "\"", "&#39;": "'", "&apos;": "'", "&lt;": "<", "&gt;": ">", "&nbsp;": " "] {
            result = result.replacingOccurrences(of: entity, with: value)
        }
        if let regex = try? NSRegularExpression(pattern: #"&#(x?)([0-9a-fA-F]+);"#) {
            for match in regex.matches(in: result, range: NSRange(result.startIndex..., in: result)).reversed() {
                guard let whole = Range(match.range, in: result),
                      let hexRange = Range(match.range(at: 1), in: result),
                      let digitsRange = Range(match.range(at: 2), in: result) else { continue }
                let radix = result[hexRange].isEmpty ? 10 : 16
                if let code = UInt32(result[digitsRange], radix: radix), let scalar = Unicode.Scalar(code) {
                    result.replaceSubrange(whole, with: String(Character(scalar)))
                }
            }
        }
        return result.replacingOccurrences(of: "&amp;", with: "&")
    }
}
