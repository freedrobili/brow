import BrowCore
import SwiftUI

/// The last screenshots taken to the clipboard: click copies one back, drag gives a PNG file.
struct ScreenshotsView: View {
    let model: AppModel
    @State private var copiedId: UUID?

    var body: some View {
        if model.screenshots.entries.isEmpty {
            Text("Сделайте скриншот через ⌘⇧5 → Сохранить в буфер обмена")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HStack(spacing: 8) {
                ForEach(model.screenshots.entries) { entry in
                    thumbnail(entry)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func thumbnail(_ entry: ScreenshotEntry) -> some View {
        ZStack {
            if let image = model.thumbnail(for: entry) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.white.opacity(0.12)
            }
            if copiedId == entry.id {
                Color.black.opacity(0.45)
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.green)
            }
        }
        .frame(width: 80, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.15)))
        .contentShape(Rectangle())
        .onTapGesture {
            model.copyScreenshot(entry)
            copiedId = entry.id
            Task {
                try? await Task.sleep(for: .seconds(1))
                if copiedId == entry.id { copiedId = nil }
            }
        }
        .onDrag {
            model.exportScreenshot(entry).flatMap { NSItemProvider(contentsOf: $0) } ?? NSItemProvider()
        }
    }
}
