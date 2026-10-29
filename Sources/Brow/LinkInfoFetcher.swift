import AppKit
import BrowCore
import os

/// Downloads a saved page's title and icon. Failures (no network, login walls)
/// leave the link showing its address; it is retried when the panel opens.
@MainActor
final class LinkInfoFetcher {
    private static let logger = Logger(subsystem: "com.freedrobili.Brow", category: "links")
    /// Enough for any <head>; stops huge pages from being read whole.
    private static let maxPageBytes = 512 * 1024

    private var running: Set<UUID> = []
    private let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        return URLSession(configuration: configuration)
    }()

    func fetch(_ link: SavedLink, done: @escaping (_ title: String?, _ icon: Data?) -> Void) {
        guard !running.contains(link.id) else { return }
        running.insert(link.id)
        Task {
            defer { running.remove(link.id) }
            do {
                let (bytes, response) = try await session.bytes(from: link.url)
                var data = Data()
                for try await byte in bytes {
                    data.append(byte)
                    if data.count >= Self.maxPageBytes { break }
                }
                let html = String(decoding: data, as: UTF8.self)
                let page = response.url ?? link.url
                let title = PageInfo.title(fromHTML: html)
                var icon: Data?
                if let iconURL = PageInfo.iconURL(fromHTML: html, page: page),
                   let (iconData, _) = try? await session.data(from: iconURL),
                   NSImage(data: iconData) != nil {
                    icon = iconData
                }
                done(title, icon)
            } catch {
                Self.logger.error("Page info failed for \(link.url.host ?? "?", privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
