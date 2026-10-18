import SwiftUI

/// The single quick note. While it has focus the panel stays open.
struct NotesView: View {
    let model: AppModel
    @FocusState private var focused: Bool

    var body: some View {
        TextEditor(text: Binding(get: { model.noteText }, set: { model.noteText = $0 }))
            .font(.system(size: 12))
            .scrollContentBackground(.hidden)
            .padding(4)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            .focused($focused)
            .onChange(of: focused) { model.setEditingNote(focused) }
            .onDisappear { model.setEditingNote(false) }
    }
}
