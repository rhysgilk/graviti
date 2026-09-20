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
                if !savedArtifactMatches.isEmpty {
                    Section("Your saves") {
                        ForEach(savedArtifactMatches) { artifact in
                            NavigationLink {
                                SavedArtifactDetailView(artifact: artifact, library: library)
                            } label: {
                                savedArtifactRow(artifact)
                            }
                        }
                    }
                }

                if !destinationMatches.isEmpty {
                    Section("Your destinations") {
                        ForEach(destinationMatches) { node in
                            NavigationLink {
                                DestinationLibraryDetailView(node: node, library: library)
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(node.name).font(.headline)
                                    Text("\(GravitiCopy.savedItems(node.saveCount)) · \(Int(node.gravity)) Gravity")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if !interestMatches.isEmpty {
                    Section("Your interests") {
                        ForEach(interestMatches) { pattern in
                            NavigationLink {
                                SearchInterestDetailView(pattern: pattern, library: library)
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(InterestDisplayName.localized(pattern.name)).font(.headline)
                                    Text(pattern.evidenceSummary)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if !savedMatches.isEmpty {
                    Section("Your places") {
                        ForEach(savedMatches) { place in
                            NavigationLink {
                                SavedPlaceDetailView(place: place, library: library)
                            } label: {
                                placeRow(place)
                            }
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
            .searchable(text: $query, prompt: "Saves, interests, or places")
            .task(id: query) { await search() }
        }
    }

    private var savedMatches: [SavedPlace] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !term.isEmpty { return localResults.places }
        var seen = Set<String>()
        return library.artifacts.compactMap(\.place).filter { place in
            seen.insert(place.id).inserted
        }
    }

    private var normalizedTerm: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var savedArtifactMatches: [Artifact] {
        localResults.artifacts
    }

    private var destinationMatches: [OrbitNode] {
        localResults.destinations
    }

    private var interestMatches: [InterestPattern] {
        localResults.interests
    }

    private var localResults: LibrarySearchResults {
        LibrarySearchEngine.search(normalizedTerm, in: library.artifacts)
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

    private func savedArtifactRow(_ artifact: Artifact) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(LibrarySearchEngine.title(for: artifact)).font(.headline).lineLimit(2)
            Text([artifact.effectiveCategory?.displayName, artifact.place?.subtitle]
                .compactMap { $0 }.joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
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
            errorMessage = String(localized: "Place search is unavailable. Your saved places are still here.")
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
            saveMessage = String(localized: "Saved \(candidate.place.name) to Graviti.")
        } catch {
            saveFailed = true
            saveMessage = error.localizedDescription
        }
    }
}

private struct SearchInterestDetailView: View {
    let pattern: InterestPattern
    @ObservedObject var library: ArtifactLibrary

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 5) {
                    Text(InterestDisplayName.localized(pattern.name))
                        .font(.custom("Sora-SemiBold", size: 26, relativeTo: .title))
                    Text(pattern.evidenceSummary)
                        .foregroundStyle(.secondary)
                    if !pattern.areaNames.isEmpty {
                        Text(pattern.areaNames.prefix(4).joined(separator: " · "))
                            .font(.subheadline)
                            .foregroundStyle(GravitiColors.signalMint)
                    }
                }
                .padding(.vertical, 8)
            }
            Section("Saves") {
                ForEach(currentArtifacts) { artifact in
                    NavigationLink {
                        SavedArtifactDetailView(artifact: artifact, library: library)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(artifact.place?.name ?? artifact.linkMetadata?.title ?? artifact.originalText ?? String(localized: "Saved item"))
                                .font(.headline)
                                .lineLimit(2)
                            if let summary = artifact.effectiveSummary {
                                Text(summary).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(GravitiColors.appBackground)
        .navigationTitle("Interest")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var currentArtifacts: [Artifact] {
        let ids = Set(pattern.artifacts.map(\.id))
        return library.artifacts.filter { ids.contains($0.id) }
    }
}
