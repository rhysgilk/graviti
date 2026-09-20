import SwiftUI

struct FitGuideView: View {
    let guide: FitGuide
    @ObservedObject var library: ArtifactLibrary
    let provider: any PlaceSearchProviding
    let onKeepGuide: () -> Void

    @State private var sections: [FitGuideSection] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var savingPlaceID: String?
    @State private var notice: String?

    private var savedArtifacts: [Artifact] {
        library.artifacts.filter(guide.contains)
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Built from your patterns")
                        .font(GravitiTypography.headline)
                    Text(InterestDisplayName.joined(guide.interests))
                        .font(GravitiTypography.subheadline)
                        .foregroundStyle(GravitiColors.signalMint)
                    Text("Suggestions follow live Apple Maps relevance. Open any result in Maps to check current ratings, hours, and details.")
                        .font(GravitiTypography.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            if !savedArtifacts.isEmpty {
                Section("Saved in this guide") {
                    ForEach(savedArtifacts) { artifact in
                        NavigationLink {
                            SavedArtifactDetailView(artifact: artifact, library: library)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(artifact.place?.name ?? artifact.originalText ?? String(localized: "Saved place"))
                                    .font(GravitiTypography.headline)
                                if let subtitle = artifact.place?.subtitle, !subtitle.isEmpty {
                                    Text(subtitle)
                                        .font(GravitiTypography.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            if isLoading {
                Section {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Finding places for your patterns…")
                    }
                }
            } else if let errorMessage {
                Section {
                    ContentUnavailableView(
                        "Suggestions unavailable",
                        systemImage: "wifi.exclamationmark",
                        description: Text(errorMessage)
                    )
                    Button("Try again") { Task { await load() } }
                }
            } else if sections.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No suggestions found",
                        systemImage: "mappin.slash",
                        description: Text("Try again later or search for the destination from the Search tab.")
                    )
                }
            } else {
                ForEach(sections) { section in
                    Section(InterestDisplayName.localized(section.interest)) {
                        ForEach(section.places) { candidate in
                            resultRow(candidate, interest: section.interest)
                        }
                    }
                }
            }

            if let notice {
                Section {
                    Text(notice)
                        .foregroundStyle(GravitiColors.signalMint)
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
        }
        .font(GravitiTypography.body)
        .scrollContentBackground(.hidden)
        .background(GravitiColors.appBackground)
        .navigationTitle(guide.collectionTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: guide.id) { await load() }
        .refreshable { await load() }
    }

    private func resultRow(_ candidate: PlaceCandidate, interest: String) -> some View {
        HStack(spacing: 12) {
            if let url = URL(string: candidate.sourceURL) {
                Link(destination: url) {
                    HStack(spacing: 8) {
                        placeLabel(candidate.place)
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the Apple Maps listing with current ratings and details")
            } else {
                placeLabel(candidate.place)
            }
            Spacer(minLength: 4)
            Button {
                Task { await save(candidate, interest: interest) }
            } label: {
                Label(isSavedInGuide(candidate) ? "Saved" : "Save", systemImage: isSavedInGuide(candidate) ? "checkmark" : "plus")
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.borderless)
            .disabled(isSavedInGuide(candidate) || savingPlaceID != nil)
            .accessibilityLabel(isSavedInGuide(candidate) ? "Saved in this Fit Guide" : "Save \(candidate.place.name) in this Fit Guide")
        }
    }

    private func placeLabel(_ place: SavedPlace) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(place.name)
                .font(GravitiTypography.headline)
            if !place.subtitle.isEmpty {
                Text(place.subtitle)
                    .font(GravitiTypography.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func isSavedInGuide(_ candidate: PlaceCandidate) -> Bool {
        savedArtifacts.contains { $0.place?.id == candidate.id }
    }

    @MainActor
    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            sections = try await FitGuideSearchEngine.search(guide: guide, using: provider)
        } catch is CancellationError {
            return
        } catch {
            sections = []
            errorMessage = String(localized: "Connect to the internet to load live place suggestions. Places already saved in this guide remain available.")
        }
        isLoading = false
    }

    @MainActor
    private func save(_ candidate: PlaceCandidate, interest: String) async {
        savingPlaceID = candidate.id
        defer { savingPlaceID = nil }
        do {
            try await library.savePlace(candidate, sourceCollectionTitle: guide.collectionTitle(for: interest))
            onKeepGuide()
            notice = String(localized: "Saved \(candidate.place.name) in \(guide.collectionTitle).")
        } catch {
            notice = error.localizedDescription
        }
    }
}
