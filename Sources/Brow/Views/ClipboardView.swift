import BrowCore
import SwiftUI

/// Searchable list of copied text; clicking a row copies it again, × removes it.
struct ClipboardView: View {
    let model: AppModel
    @State private var query = ""
    @State private var copiedId: UUID?

    var body: some View {
        let results = model.clipboard.search(query)
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                TextField("Поиск", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                if !model.clipboard.entries.isEmpty {
                    Button("Очистить всё") { model.clearHistory() }
                        .buttonStyle(.plain)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            if results.isEmpty {
                Text(query.isEmpty ? "История пуста" : "Ничего не найдено")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(results) { entry in
                            row(entry)
                        }
                    }
                }
            }
        }
    }

    private func row(_ entry: ClipboardEntry) -> some View {
        HStack(spacing: 4) {
            copyButton(entry)
            Button { model.removeFromHistory(entry.id) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func copyButton(_ entry: ClipboardEntry) -> some View {
        Button {
            model.copyFromHistory(entry)
            copiedId = entry.id
            Task {
                try? await Task.sleep(for: .seconds(1))
                if copiedId == entry.id { copiedId = nil }
            }
        } label: {
            HStack(spacing: 6) {
                Text(entry.preview.replacingOccurrences(of: "\n", with: " "))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if copiedId == entry.id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.green)
                }
            }
            .font(.system(size: 11))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
