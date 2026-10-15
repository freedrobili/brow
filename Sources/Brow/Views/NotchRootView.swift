import BrowCore
import SwiftUI
import UniformTypeIdentifiers

/// The black shape that grows out of the notch.
struct NotchRootView: View {
    let model: AppModel
    @State private var isDropTargeted = false

    var body: some View {
        let expanded = model.isExpanded
        let notch = model.panel?.geometry.notchRect.size ?? .zero
        let size = expanded ? NotchGeometry.expandedSize : notch
        let radius: CGFloat = expanded ? 24 : 8

        ZStack(alignment: .top) {
            UnevenRoundedRectangle(bottomLeadingRadius: radius, bottomTrailingRadius: radius)
                .fill(.black)
            if expanded {
                content
                    .padding(.top, notch.height)
                    .transition(.opacity)
            }
        }
        .frame(width: size.width, height: size.height)
        .overlay {
            if isDropTargeted {
                UnevenRoundedRectangle(bottomLeadingRadius: radius, bottomTrailingRadius: radius)
                    .strokeBorder(.white.opacity(0.6), lineWidth: 2)
            }
        }
        .onDrop(of: [.fileURL, .plainText], isTargeted: $isDropTargeted) { providers in
            for provider in providers {
                if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        guard let url else { return }
                        DispatchQueue.main.async { MainActor.assumeIsolated { model.addToShelf([url]) } }
                    }
                } else {
                    _ = provider.loadObject(ofClass: String.self) { text, _ in
                        guard let text else { return }
                        DispatchQueue.main.async { MainActor.assumeIsolated { model.addDroppedText(text) } }
                    }
                }
            }
            return true
        }
        .contextMenu {
            Button("Выйти из Brow") { NSApp.terminate(nil) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: expanded)
    }

    private var content: some View {
        VStack(spacing: 6) {
            MusicView(model: model)
                .frame(height: 56)
            tabBar
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .foregroundStyle(.white)
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(PanelTab.allCases, id: \.self) { tab in
                Button { model.select(tab) } label: {
                    Image(systemName: tab.symbol)
                        .frame(width: 32, height: 22)
                        .background(model.panel?.selectedTab == tab ? Color.white.opacity(0.18) : .clear,
                                    in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    @ViewBuilder private var tabContent: some View {
        switch model.panel?.selectedTab ?? .shelf {
        case .shelf: ShelfView(model: model)
        case .clipboard: ClipboardView(model: model)
        case .screenshots: ScreenshotsView(model: model)
        case .notes: NotesView(model: model)
        }
    }
}

extension PanelTab {
    var symbol: String {
        switch self {
        case .shelf: "tray"
        case .clipboard: "doc.on.clipboard"
        case .screenshots: "camera.viewfinder"
        case .notes: "note.text"
        }
    }
}
