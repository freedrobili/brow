import AppKit
import BrowCore
import SwiftUI

/// Now playing row: artwork, title, progress and transport buttons.
struct MusicView: View {
    let model: AppModel
    /// Slider value while the user drags it; cleared when fresh status arrives.
    @State private var scrubPosition: TimeInterval?

    var body: some View {
        HStack(spacing: 12) {
            artwork
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
                if case .playing(let nowPlaying) = model.media, let duration = nowPlaying.duration, duration > 0 {
                    progress(nowPlaying, duration: duration)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            controls
        }
        .onChange(of: model.media) { scrubPosition = nil }
    }

    private var title: String {
        switch model.media {
        case .unavailable: "Нет данных о воспроизведении"
        case .nothing: "Ничего не играет"
        case .playing(let nowPlaying): nowPlaying.title
        }
    }

    /// The artist, or the playing app's name for browser videos that have no artist.
    private var subtitle: String? {
        guard case .playing(let nowPlaying) = model.media else { return nil }
        if !nowPlaying.artist.isEmpty { return nowPlaying.artist }
        guard let bundleId = nowPlaying.bundleId,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else { return nil }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    @ViewBuilder private var artwork: some View {
        if case .playing(let nowPlaying) = model.media,
           let data = nowPlaying.artwork, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(.white.opacity(0.12))
                .frame(width: 48, height: 48)
                .overlay(Image(systemName: "music.note").foregroundStyle(.white.opacity(0.6)))
        }
    }

    private func progress(_ nowPlaying: NowPlaying, duration: TimeInterval) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let position = scrubPosition ?? nowPlaying.position(at: context.date) ?? 0
            HStack(spacing: 6) {
                Slider(value: Binding(get: { position }, set: { scrubPosition = $0 }),
                       in: 0...duration,
                       onEditingChanged: { editing in
                           if !editing, let target = scrubPosition { model.sendMedia(.seek(target)) }
                       })
                    .controlSize(.mini)
                    .tint(.white)
                Text("\(Self.format(position)) / \(Self.format(duration))")
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize()
            }
        }
    }

    private var controls: some View {
        let isPlaying = if case .playing(let nowPlaying) = model.media { nowPlaying.isPlaying } else { false }
        return HStack(spacing: 14) {
            button("backward.fill", size: 14) { model.sendMedia(.previous) }
            button(isPlaying ? "pause.fill" : "play.fill", size: 20) { model.sendMedia(.toggle) }
            button("forward.fill", size: 14) { model.sendMedia(.next) }
        }
        .disabled(model.media == .unavailable)
        .opacity(model.media == .unavailable ? 0.35 : 1)
    }

    private func button(_ symbol: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private static func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.down))
        let (hours, minutes, secs) = (total / 3600, total % 3600 / 60, total % 60)
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, secs)
                         : String(format: "%d:%02d", minutes, secs)
    }
}
