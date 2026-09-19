import SwiftUI

struct SearchView: View {
    @ObservedObject var library: ArtifactLibrary
    let provider: any PlaceSearchProviding

    @Binding var query: String
    @State private var results: [PlaceCandidate] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var savingID: String?
    @State private var saveMessage: String?
    @State private var saveFailed = false

    var body: some View {
        NavigationStack {
            List {
                if !savedMatches.isEmpty {
                    Section("Your places") {
                        ForEach(savedMatches) { place in
                            placeRow(place)
                        }
                    }
                }

                if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section("Find places") {
                        if isSearching {
                            ProgressView("Searching places")
                        } else if let errorMessage {
                            Text(errorMessage)
                                .foregroundStyle(GravitiColors.opportunityCoral)
                        } else if results.isEmpty {
                            Text(query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2
                                 ? "Enter at least two characters."
                                 : "No places found. Try a name and city.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(results) { candidate in
                                HStack(spacing: 12) {
                                    placeRow(candidate.place)
                                    Spacer(minLength: 4)
                                    Button {
                                        Task { await save(candidate) }
                                    } label: {
                                        Label(isSaved(candidate) ? "Saved" : "Save", systemImage: isSaved(candidate) ? "checkmark" : "plus")
                                            .labelStyle(.iconOnly)
                                            .frame(minWidth: 44, minHeight: 44)
                                    }
                                    .disabled(isSaved(candidate) || savingID != nil)
                                    .accessibilityLabel(isSaved(candidate) ? "Already saved" : "Save \(candidate.place.name)")
                                }
                            }
                        }
                    }
                } else if savedMatches.isEmpty {
                    ContentUnavailableView(
                        "Find a place",
                        systemImage: "magnifyingglass",
                        description: Text("Search for a café, landmark, or address to save it to Graviti.")
                    )
                    .listRowBackground(Color.clear)
                }

                if let saveMessage {
                    Text(saveMessage)
                        .foregroundStyle(saveFailed ? GravitiColors.opportunityCoral : GravitiColors.signalMint)
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
            .scrollContentBackground(.hidden)
            .background(GravitiColors.appBackground)
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Places and addresses")
            .task(id: query) { await search() }
        }
    }

    private var savedMatches: [SavedPlace] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var seen = Set<String>()
        return library.artifacts.compactMap(\.place).filter { place in
            seen.insert(place.id).inserted &&
                (term.isEmpty || place.name.localizedCaseInsensitiveContains(term) ||
                 place.subtitle.localizedCaseInsensitiveContains(term))
        }
    }

    private func placeRow(_ place: SavedPlace) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(place.name).font(.headline)
            if !place.subtitle.isEmpty {
                Text(place.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func isSaved(_ candidate: PlaceCandidate) -> Bool {
        library.artifacts.contains { $0.place?.id == candidate.id }
    }

    private func search() async {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        results = []
        errorMessage = nil
        guard term.count >= 2 else {
            isSearching = false
            return
        }
        isSearching = true
        do {
            try await Task.sleep(for: .milliseconds(350))
            let found = try await provider.search(term)
            guard !Task.isCancelled else { return }
            results = Array(found.prefix(20))
            isSearching = false
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = "Place search is unavailable. Your saved places are still here."
            isSearching = false
        }
    }

    private func save(_ candidate: PlaceCandidate) async {
        guard !isSaved(candidate) else { return }
        savingID = candidate.id
        defer { savingID = nil }
        do {
            try await library.savePlace(candidate)
            saveFailed = false
            saveMessage = "Saved \(candidate.place.name) to Graviti."
        } catch {
            saveFailed = true
            saveMessage = error.localizedDescription
        }
    }
}
