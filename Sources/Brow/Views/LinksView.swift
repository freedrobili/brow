import AppKit
import BrowCore
import SwiftUI

/// Saved links: click opens in the default browser, double-click renames.
struct LinksView: View {
    let model: AppModel
    @State private var renamingId: UUID?
    @State private var draftName = ""
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Button { model.addLinkFromPasteboard() } label: {
                    Label("из буфера", systemImage: "plus")
                        .font(.system(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(model.pasteboardLink == nil ? 0.25 : 0.8))
                .disabled(model.pasteboardLink == nil)
                .help(model.pasteboardLink == nil ? "Скопируйте ссылку, чтобы сохранить её" : "Сохранить ссылку из буфера обмена")
                Spacer()
                if !model.links.links.isEmpty {
                    PanelTextButton("Очистить всё") { model.clearLinks() }
                }
            }
            if model.links.links.isEmpty {
                Text("Перетащите ссылку из браузера на вырез или скопируйте её и нажмите «+ из буфера»")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(model.links.links) { link in
                            row(link)
                        }
                    }
                }
            }
        }
    }

    private func row(_ link: SavedLink) -> some View {
        HStack(spacing: 6) {
            icon(link)
            if renamingId == link.id {
                TextField("Название", text: $draftName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .focused($nameFieldFocused)
                    .onSubmit { finishRenaming(link) }
                    .onExitCommand { cancelRenaming() }
                    .onChange(of: nameFieldFocused) { _, focused in
                        if !focused && renamingId == link.id { finishRenaming(link) }
                    }
            } else {
                Text(link.displayTitle)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .truncationMode(.tail)
                if link.customTitle != nil || link.pageTitle != nil {
                    Text(link.url.host ?? "")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(1)
                        .layoutPriority(-1)
                }
            }
            Spacer(minLength: 4)
            RemoveButton(symbol: "xmark", size: 9, hitArea: CGSize(width: 26, height: 20)) {
                model.removeLink(link.id)
            }
            .foregroundStyle(.white.opacity(0.45))
        }
        .padding(.horizontal, 6)
        .frame(height: 20)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { startRenaming(link) }
        .onTapGesture { if renamingId != link.id { model.openLink(link) } }
        .contextMenu {
            Button("Открыть") { model.openLink(link) }
            Button("Переименовать") { startRenaming(link) }
            Button("Скопировать ссылку") { model.copyLink(link) }
            Divider()
            Button("Удалить") { model.removeLink(link.id) }
        }
    }

    @ViewBuilder private func icon(_ link: SavedLink) -> some View {
        if let data = link.icon, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: 14, height: 14)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        } else {
            Image(systemName: "globe")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 14, height: 14)
        }
    }

    private func startRenaming(_ link: SavedLink) {
        draftName = link.customTitle ?? link.pageTitle ?? ""
        renamingId = link.id
        model.setEditingNote(true)   // keep the panel open while typing
        model.focusPanel?()          // a double-click on a row does not make the panel key by itself
        nameFieldFocused = true
    }

    private func finishRenaming(_ link: SavedLink) {
        model.renameLink(link.id, to: draftName)
        cancelRenaming()
    }

    private func cancelRenaming() {
        renamingId = nil
        nameFieldFocused = false
        model.setEditingNote(false)
    }
}
