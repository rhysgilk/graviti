import SwiftUI
import MapKit

struct LibraryView: View {
    @ObservedObject var library: ArtifactLibrary
    @State private var mode: LibraryMode = .saves
    @State private var selectedMapPlace: SavedPlace?
    @State private var query = ""
    @State private var showsNeedsReviewOnly = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                modePicker

                if needsReviewCount > 0 || showsNeedsReviewOnly {
                    reviewFilter
                }

                Group {
                    switch mode {
                    case .destinations:
                        destinationsContent
                    case .places:
                        placesContent
                    case .saves:
                        savesContent
                    case .map:
                        mapContent
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(GravitiColors.appBackground)
            .navigationTitle("Library")
            .searchable(text: $query, prompt: "Places, interests, and saves")
            .onChange(of: query) { _, _ in
                if let selectedMapPlace, !savedPlaces.contains(where: { $0.id == selectedMapPlace.id }) {
                    self.selectedMapPlace = nil
                }
            }
            .onChange(of: needsReviewCount) { _, count in
                if count == 0 { showsNeedsReviewOnly = false }
            }
        }
    }

    private var reviewFilter: some View {
        Button {
            showsNeedsReviewOnly.toggle()
            if showsNeedsReviewOnly { mode = .saves }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.bubble.fill")
                Text("Needs your help")
                    .fontWeight(.semibold)
                Spacer()
                Text(needsReviewCount, format: .number)
                    .font(.caption.weight(.bold))
                    .frame(minWidth: 28, minHeight: 28)
                    .background(.white.opacity(0.12), in: Circle())
                Image(systemName: showsNeedsReviewOnly ? "checkmark.circle.fill" : "chevron.forward")
            }
            .font(.subheadline)
            .foregroundStyle(showsNeedsReviewOnly ? .white : GravitiColors.opportunityCoral)
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
            .background(
                showsNeedsReviewOnly ? GravitiColors.opportunityCoral.opacity(0.32) : GravitiColors.deepInk,
                in: RoundedRectangle(cornerRadius: 14)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .accessibilityValue(showsNeedsReviewOnly ? "Showing only items that need review" : "")
    }

    private var modePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LibraryMode.allCases) { option in
                    Button {
                        mode = option
                    } label: {
                        Text(option.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(mode == option ? .white : .white.opacity(0.68))
                            .padding(.horizontal, 16)
                            .frame(minHeight: 44)
                            .background(
                                mode == option ? GravitiColors.iris : GravitiColors.deepInk,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(mode == option ? .isSelected : [])
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    @ViewBuilder
    private var destinationsContent: some View {
        let destinations = DestinationOrbitBuilder.nodes(from: filteredArtifacts, limit: nil)
        if destinations.isEmpty {
            if query.isEmpty {
                emptyState("No destinations yet", icon: "globe", detail: "Destinations appear as your saves are connected to places.")
            } else {
                noResultsState()
            }
        } else {
            List(destinations) { node in
                NavigationLink {
                    DestinationLibraryDetailView(node: node, library: library)
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(node.name).font(.headline)
                        Text("\(node.level.displayName) · \(node.saveCount) saved \(node.saveCount == 1 ? "item" : "items")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(GravitiColors.deepInk)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    @ViewBuilder
    private var placesContent: some View {
        if savedPlaces.isEmpty {
            if query.isEmpty {
                emptyState("No places yet", icon: "mappin.and.ellipse", detail: "Search for a place to add it here.")
            } else {
                noResultsState()
            }
        } else {
            List(savedPlaces) { place in
                NavigationLink {
                    SavedPlaceDetailView(place: place, library: library)
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(place.name).font(.headline)
                        Text(place.subtitle).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(GravitiColors.deepInk)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    @ViewBuilder
    private var mapContent: some View {
        if savedPlaces.isEmpty {
            if query.isEmpty {
                emptyState("No places on the map yet", icon: "map", detail: "Saved places will appear here when their locations are known.")
            } else {
                noResultsState()
            }
        } else {
            Map(initialPosition: .automatic, selection: $selectedMapPlace) {
                ForEach(savedPlaces) { place in
                    Marker(place.name, coordinate: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude))
                        .tag(place)
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .sheet(item: $selectedMapPlace) { place in
                NavigationStack {
                    SavedPlaceDetailView(place: place, library: library)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { selectedMapPlace = nil }
                            }
                        }
                }
            }
        }
    }

    private var savedPlaces: [SavedPlace] {
        var seen = Set<String>()
        return filteredArtifacts.compactMap(\.place).filter { seen.insert($0.id).inserted }
    }

    private var filteredArtifacts: [Artifact] {
        let reviewFiltered = showsNeedsReviewOnly
            ? library.artifacts.filter(\.needsPlaceReview)
            : library.artifacts
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return reviewFiltered }
        return reviewFiltered.filter { $0.librarySearchText.localizedCaseInsensitiveContains(term) }
    }

    private var needsReviewCount: Int {
        library.artifacts.lazy.filter(\.needsPlaceReview).count
    }

    @ViewBuilder
    private var savesContent: some View {
        if let error = library.loadError {
            ContentUnavailableView {
                Label("Library couldn't load", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error)
            } actions: {
                Button("Try Again") { Task { await library.load() } }
            }
        } else if filteredArtifacts.isEmpty {
            if query.isEmpty {
                emptyState("No saves yet", icon: "square.stack", detail: "Save a link or note to start your library.")
            } else {
                noResultsState()
            }
        } else {
            List(filteredArtifacts) { artifact in
                NavigationLink {
                    SavedArtifactDetailView(artifact: artifact, library: library)
                } label: {
                    ArtifactRow(artifact: artifact)
                }
                .listRowBackground(GravitiColors.deepInk)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private func emptyState(_ title: LocalizedStringKey, icon: String, detail: LocalizedStringKey) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            Text(detail)
        }
    }

    private func noResultsState() -> some View {
        ContentUnavailableView.search(text: query)
    }
}

private enum LibraryMode: String, CaseIterable, Identifiable {
    case destinations
    case places
    case saves
    case map

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .destinations: "Destinations"
        case .places: "Places"
        case .saves: "Saves"
        case .map: "Map"
        }
    }
}

private struct ArtifactRow: View {
    let artifact: Artifact

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: artifact.kind == .url ? "link" : (artifact.kind == .photo ? "photo" : "note.text"))
                .font(.title3)
                .foregroundStyle(GravitiColors.signalMint)
                .frame(width: 44, height: 44)
                .background(GravitiColors.appBackground, in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 5) {
                Text(artifact.libraryTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(artifact.capturedAt, format: .dateTime.month().day().year())
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))

                if artifact.processingState == .needsReview || artifact.processingState == .failed {
                    Text(artifact.processingState == .needsReview ? "Needs place review" : "Place lookup failed")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(GravitiColors.opportunityCoral)
                }

                if let category = artifact.effectiveCategory {
                    Text(category.displayName)
                        .font(.caption)
                        .foregroundStyle(GravitiColors.signalMint)
                }
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

}

private extension Artifact {
    var needsPlaceReview: Bool {
        processingState == .needsReview || processingState == .failed
    }

    var libraryTitle: String {
        switch kind {
        case .url:
            if let title = originalText, !title.isEmpty { return title }
            guard let source = sourceURL else { return "Saved link" }
            if MapLinkMetadata.isCollectionLink(source),
               let provider = MapLinkMetadata.provider(for: source) {
                return provider == .apple ? "Apple Maps guide" : "Google Maps list"
            }
            return URLComponents(string: source)?.host ?? source
        case .manual:
            return originalText?.split(whereSeparator: \.isNewline).first.map(String.init) ?? "Saved note"
        case .photo:
            return userNote?.split(whereSeparator: \.isNewline).first.map(String.init) ?? "Saved photo"
        }
    }

    var librarySearchText: String {
        [
            libraryTitle,
            sourceURL,
            originalText,
            userNote,
            effectiveSummary,
            effectiveCategory?.displayName,
            effectiveInterests.joined(separator: " "),
            place?.name,
            place?.locality,
            place?.region,
            place?.country
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }
}
