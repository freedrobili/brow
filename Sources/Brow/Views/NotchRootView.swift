import BrowCore
import SwiftUI

/// The black shape that grows out of the notch.
struct NotchRootView: View {
    let model: AppModel

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
        .contextMenu {
            Button("Выйти из Brow") { NSApp.terminate(nil) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: expanded)
    }

    private var content: some View {
        VStack(spacing: 6) {
            Color.clear.frame(height: 56)   // music
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
        case .shelf: Color.clear
        case .clipboard: Color.clear
        case .notes: Color.clear
        }
    }
}

extension PanelTab {
    var symbol: String {
        switch self {
        case .shelf: "tray"
        case .clipboard: "doc.on.clipboard"
        case .notes: "note.text"
        }
    }
}
