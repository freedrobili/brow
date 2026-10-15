import SwiftUI

// Plain SwiftUI buttons only react to the drawn pixels of their label, so a
// click a hair off a thin glyph or between letters is lost. These give small
// labels a full rectangular hit area.

/// A small "×" that removes something; clickable across `hitArea` around the glyph.
struct RemoveButton: View {
    var symbol = "xmark.circle.fill"
    var size: CGFloat = 12
    var hitArea = CGSize(width: 22, height: 22)
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .frame(width: hitArea.width, height: hitArea.height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A quiet text action such as «Очистить всё»; clickable across its padded box.
struct PanelTextButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
