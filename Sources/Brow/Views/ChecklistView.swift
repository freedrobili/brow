import BrowCore
import SwiftUI

/// The to-do half of the notes tab: Enter adds, the circle checks, double-click renames.
struct ChecklistView: View {
    let model: AppModel
    @State private var newTask = ""
    @State private var renamingId: UUID?
    @State private var draft = ""
    @FocusState private var focus: Field?

    private enum Field: Hashable {
        case newTask
        case rename
    }

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 6) {
                TextField("Новая задача…", text: $newTask)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
                    .focused($focus, equals: .newTask)
                    .onSubmit {
                        model.addTask(newTask)
                        newTask = ""
                        focus = .newTask   // keep typing the next one
                    }
                if model.checklist.hasDone {
                    // An icon, not text: the half-width field needs the room.
                    RemoveButton(symbol: "eraser", size: 11, hitArea: CGSize(width: 24, height: 20)) {
                        model.removeDoneTasks()
                    }
                    .foregroundStyle(.white.opacity(0.6))
                    .help("Убрать выполненные")
                    .accessibilityLabel("Убрать выполненные")
                }
            }
            if model.checklist.items.isEmpty {
                Text("Пока пусто")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(model.checklist.items) { item in
                            row(item)
                        }
                    }
                }
            }
        }
        // While typing here the panel stays open, as with the note.
        .onChange(of: focus) { _, field in model.setEditingNote(field != nil) }
    }

    private func row(_ item: ChecklistItem) -> some View {
        HStack(spacing: 4) {
            Button { model.toggleTask(item.id) } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 12))
                    .foregroundStyle(item.isDone ? .green : .white.opacity(0.6))
                    .frame(width: 20, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if renamingId == item.id {
                TextField("Задача", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .focused($focus, equals: .rename)
                    .onSubmit { finishRenaming(item) }
                    .onExitCommand { renamingId = nil; focus = nil }
                    .onChange(of: focus) { _, field in
                        if field != .rename && renamingId == item.id { finishRenaming(item) }
                    }
            } else {
                Text(item.text)
                    .font(.system(size: 11))
                    .strikethrough(item.isDone)
                    .foregroundStyle(.white.opacity(item.isDone ? 0.45 : 1))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { startRenaming(item) }
            }
            RemoveButton(symbol: "xmark", size: 8, hitArea: CGSize(width: 22, height: 18)) {
                model.removeTask(item.id)
            }
            .foregroundStyle(.white.opacity(0.4))
        }
        .frame(height: 18)
    }

    private func startRenaming(_ item: ChecklistItem) {
        draft = item.text
        renamingId = item.id
        model.focusPanel?()   // a double-click on text does not make the panel key by itself
        focus = .rename
    }

    private func finishRenaming(_ item: ChecklistItem) {
        model.renameTask(item.id, to: draft)
        renamingId = nil
    }
}
