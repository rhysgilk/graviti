import SwiftUI

struct SavedLibraryFiltersView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filtersJSON: String
    let onSelect: (UUID) -> Void
    @State private var editingFilter: SavedLibraryFilter?
    @State private var creatingFilter = false

    private var filters: [SavedLibraryFilter] { SavedLibraryFilterStore.decode(filtersJSON) }

    var body: some View {
        NavigationStack {
            List {
                if filters.isEmpty {
                    ContentUnavailableView(
                        "No saved views",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text("Combine place, interest, category, source, note, and status rules into a view that updates automatically.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(filters) { filter in
                        Button {
                            onSelect(filter.id)
                            dismiss()
                        } label: {
                            HStack {
                                Label(filter.name, systemImage: "line.3.horizontal.decrease.circle.fill")
                                Spacer()
                                Button { editingFilter = filter } label: { Image(systemName: "pencil") }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel("Edit \(filter.name)")
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) { delete(filter.id) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(GravitiColors.appBackground)
            .navigationTitle("Saved Views")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { creatingFilter = true } label: { Label("New view", systemImage: "plus") }
                }
            }
            .sheet(isPresented: $creatingFilter) {
                SavedLibraryFilterEditor { save($0) }
            }
            .sheet(item: $editingFilter) { filter in
                SavedLibraryFilterEditor(filter: filter) { save($0) }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func save(_ filter: SavedLibraryFilter) {
        var values = filters
        if let index = values.firstIndex(where: { $0.id == filter.id }) { values[index] = filter }
        else { values.append(filter) }
        filtersJSON = SavedLibraryFilterStore.encode(values, fallback: filtersJSON)
    }

    private func delete(_ id: UUID) {
        filtersJSON = SavedLibraryFilterStore.encode(filters.filter { $0.id != id }, fallback: filtersJSON)
    }
}

private struct SavedLibraryFilterEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var value: SavedLibraryFilter
    let onSave: (SavedLibraryFilter) -> Void

    init(filter: SavedLibraryFilter? = nil, onSave: @escaping (SavedLibraryFilter) -> Void) {
        _value = State(initialValue: filter ?? SavedLibraryFilter(
            id: UUID(), name: "", category: nil, placeQuery: "", interestQuery: "",
            noteRule: .any, sourceRule: .any, lifecycle: nil,
            recentlyAdded: false, needsDescription: false, highPriorityOnly: false
        ))
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("View name") { TextField("Weekend ideas", text: $value.name) }
                Section("Match all selected rules") {
                    Picker("Category", selection: $value.category) {
                        Text("Any category").tag(ExperienceCategory?.none)
                        ForEach(ExperienceCategory.allCases, id: \.self) { Text($0.displayName).tag(Optional($0)) }
                    }
                    TextField("Place or area", text: $value.placeQuery)
                    TextField("Interest", text: $value.interestQuery)
                    Picker("Notes", selection: $value.noteRule) {
                        ForEach(SavedLibraryNoteRule.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Source", selection: $value.sourceRule) {
                        ForEach(SavedLibrarySourceRule.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Place status", selection: $value.lifecycle) {
                        Text("Any status").tag(PlaceLifecycleStatus?.none)
                        ForEach(PlaceLifecycleStatus.allCases) { Text($0.title).tag(Optional($0)) }
                    }
                    Toggle("Added in the last 30 days", isOn: $value.recentlyAdded)
                    Toggle("Needs a description", isOn: $value.needsDescription)
                    Toggle("High priority only", isOn: $value.highPriorityOnly)
                }
            }
            .navigationTitle("Saved View")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        value.name = value.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        value.placeQuery = value.placeQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                        value.interestQuery = value.interestQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(value)
                        dismiss()
                    }
                    .disabled(value.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
