import AppKit
import BrowCore
import SwiftUI

/// Files parked on the shelf; each tile can be dragged back out.
struct ShelfView: View {
    let model: AppModel

    var body: some View {
        if model.shelf.items.isEmpty {
            Text("Перетащите файлы сюда")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.5))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HStack(alignment: .top, spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(model.shelf.items) { item in
                            tile(item)
                        }
                    }
                }
                Button("Очистить всё") { model.clearShelf() }
                    .buttonStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    private func tile(_ item: ShelfItem) -> some View {
        VStack(spacing: 2) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                .resizable()
                .frame(width: 36, height: 36)
            Text(item.name)
                .font(.system(size: 9))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(width: 64, height: 60)
        .contentShape(Rectangle())
        .onDrag { NSItemProvider(object: item.url as NSURL) }
        .overlay(alignment: .topTrailing) {
            Button { model.removeFromShelf(item.id) } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
    }
}
