import SwiftUI

struct PlaceReviewView: View {
    @Environment(\.dismiss) private var dismiss
    let artifact: Artifact
    @ObservedObject var library: ArtifactLibrary

    @State private var query: String
    @State private var results: [PlaceCandidate] = []
    @State private var isSearching = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    @MainActor init(artifact: Artifact, library: ArtifactLibrary) {
        self.artifact = artifact
        self.library = library
        _query = State(initialValue: artifact.sourceURL.flatMap(MapLinkMetadata.placeName)
            ?? artifact.originalText ?? "")
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Place name and city", text: $query)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.search)
                        .onSubmit { Task { await search() } }

                    Button {
                        Task { await search() }
                    } label: {
                        if isSearching {
                            ProgressView("Searching")
                        } else {
                            Label("Search places", systemImage: "magnifyingglass")
                        }
                    }
                    .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 || isSearching)
                } header: {
                    Text(artifact.kind == .photo ? "Find the place in this photo" : "Find the place in this save")
                } footer: {
                    Text(artifact.kind == .photo
                         ? "The photo stays in your Library even if you leave it unmatched."
                         : "The original link stays in your Library even if you leave this unmatched.")
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(GravitiColors.opportunityCoral)
                }

                if !results.isEmpty {
                    Section("Matches") {
                        ForEach(results) { candidate in
                            Button {
                                Task { await choose(candidate) }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(candidate.place.name).font(.headline)
                                    Text(candidate.place.subtitle)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 5)
                            }
                            .disabled(isSaving)
                            .accessibilityHint("Associates this saved item with the selected place")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(GravitiColors.appBackground)
            .navigationTitle("Review place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func search() async {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard term.count >= 2 else { return }
        isSearching = true
        errorMessage = nil
        results = []
        do {
            results = Array(try await MapKitPlaceSearchProvider().search(term).prefix(20))
            if results.isEmpty { errorMessage = "No matches. Try the place name with its city." }
        } catch {
            errorMessage = "Place search is unavailable. Try again when you're online."
        }
        isSearching = false
    }

    private func choose(_ candidate: PlaceCandidate) async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await library.assignPlace(candidate.place, to: artifact.id)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
