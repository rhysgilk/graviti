import SwiftUI

struct SavedItemDetailsEditor: View {
    @Environment(\.dismiss) private var dismiss
    let artifact: Artifact
    @ObservedObject var library: ArtifactLibrary

    @State private var note: String
    @State private var summary: String
    @State private var category: ExperienceCategory
    @State private var interests: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(artifact: Artifact, library: ArtifactLibrary) {
        self.artifact = artifact
        self.library = library
        _note = State(initialValue: artifact.userNote ?? "")
        _summary = State(initialValue: artifact.effectiveSummary ?? "")
        _category = State(initialValue: artifact.effectiveCategory ?? .other)
        _interests = State(initialValue: artifact.effectiveInterests.joined(separator: ", "))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(artifact.kind == .photo ? "Your photo description" : "Your note") {
                    TextEditor(text: $note)
                        .frame(minHeight: 90)
                }
                Section("About this save") {
                    TextField("Short description", text: $summary, axis: .vertical)
                        .lineLimit(2...4)
                    Picker("Category", selection: $category) {
                        ForEach(ExperienceCategory.allCases, id: \.self) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    TextField("Interests, separated by commas", text: $interests, axis: .vertical)
                        .lineLimit(2...4)
                    Text("Examples: matcha, scenic views, architecture. These help Graviti find patterns across your saves.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if artifact.userDetails != nil {
                    Section {
                        Button("Use suggested details") {
                            Task { await save(details: nil) }
                        }
                        .disabled(isSaving)
                    } footer: {
                        Text("Your note stays in place. Refreshed suggestions will become visible again.")
                    }
                }
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(GravitiColors.opportunityCoral)
                }
            }
            .navigationTitle("Edit saved item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save(details: editedDetails) } }
                        .disabled(isSaving)
                }
            }
        }
    }

    private var editedDetails: ArtifactUserDetails {
        var seen = Set<String>()
        let tags = interests.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.folding(options: .caseInsensitive, locale: .current)).inserted }
        let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        return ArtifactUserDetails(
            summary: trimmedSummary.isEmpty ? nil : trimmedSummary,
            category: category == .other ? nil : category,
            interests: tags
        )
    }

    private func save(details: ArtifactUserDetails?) async {
        isSaving = true
        defer { isSaving = false }
        do {
            let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
            try await library.saveEditedDetails(details, note: trimmedNote.isEmpty ? nil : trimmedNote, for: artifact.id)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
