import SwiftUI

/// The notes tab: the quick note on the left, the to-do list on the right.
/// While the note has focus the panel stays open.
struct NotesView: View {
    let model: AppModel
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            TextEditor(text: Binding(get: { model.noteText }, set: { model.noteText = $0 }))
                .font(.system(size: 12))
                .scrollContentBackground(.hidden)
                .padding(4)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                .focused($focused)
                .onChange(of: focused) { model.setEditingNote(focused) }
                .frame(maxWidth: .infinity)
            ChecklistView(model: model)
                .frame(maxWidth: .infinity)
        }
        .onDisappear { model.setEditingNote(false) }
    }
}
