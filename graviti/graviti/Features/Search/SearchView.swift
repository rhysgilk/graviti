import SwiftUI
import CoreLocation
import UIKit

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
    @State private var scope: SearchScope = .all
    @StateObject private var locationManager = SearchLocationManager()
    @AppStorage("search.recentQueries") private var recentQueriesRaw = ""
    @AppStorage("fitGuide.library.v1") private var guideLibraryJSON = ""
    @AppStorage("fitGuide.metadata.v1") private var guideMetadataJSON = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(SearchScope.allCases) { option in
                                Button {
                                    scope = option
                                } label: {
                                    Label(option.title, systemImage: option.symbol)
                                        .font(GravitiTypography.captionSemibold)
                                        .padding(.horizontal, 13)
                                        .frame(minHeight: 36)
                                        .foregroundStyle(scope == option ? .white : .secondary)
                                        .background(scope == option ? GravitiColors.iris : GravitiColors.deepInk, in: Capsule())
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(scope == option ? .isSelected : [])
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
                }

                if normalizedTerm.isEmpty {
                    suggestions
                }

                if scope == .nearMe {
                    nearbyLocationStatus
                }

                if scope.shows(.notes), !savedArtifactMatches.isEmpty {
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

                if scope.shows(.destinations), !destinationMatches.isEmpty {
                    Section("Your destinations") {
                        ForEach(destinationMatches) { node in
                            NavigationLink {
                                DestinationLibraryDetailView(node: node, library: library)
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(node.name).font(GravitiTypography.headline)
                                    Text("\(GravitiCopy.savedItems(node.saveCount)) · \(Int(node.gravity)) Gravity")
                                        .font(GravitiTypography.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if scope.shows(.interests), !interestMatches.isEmpty {
                    Section("Your interests") {
                        ForEach(interestMatches) { pattern in
                            NavigationLink {
                                SearchInterestDetailView(pattern: pattern, library: library)
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(InterestDisplayName.localized(pattern.name)).font(GravitiTypography.headline)
                                    Text(pattern.evidenceSummary)
                                        .font(GravitiTypography.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if scope.shows(.guides), !normalizedTerm.isEmpty, !matchingGuides.isEmpty {
                    Section("Saved guides") {
                        ForEach(matchingGuides) { guide in
                            guideLink(guide)
                        }
                    }
                }

                if scope.showsSavedPlaces, !savedMatches.isEmpty {
                    Section(scope == .nearMe ? "Saved nearby" : "Your places") {
                        ForEach(savedMatches) { place in
                            NavigationLink {
                                SavedPlaceDetailView(place: place, library: library)
                            } label: {
                                placeRow(place, includesDistance: scope == .nearMe)
                            }
                        }
                    }
                }

                if !normalizedTerm.isEmpty, scope.showsRemotePlaces {
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
                                    placeRow(candidate.place, includesDistance: scope == .nearMe)
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
                } else if normalizedTerm.isEmpty && library.artifacts.isEmpty {
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
            .onChange(of: scope) { _, newValue in
                if newValue == .nearMe { locationManager.requestLocation() }
            }
            .onChange(of: locationManager.location) { _, location in
                if scope == .nearMe, let location {
                    results = NearbyPlaceSorter.sort(results, from: location)
                }
            }
        }
        .font(GravitiTypography.body)
    }

    private var savedMatches: [SavedPlace] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let places: [SavedPlace]
        if !term.isEmpty {
            places = localResults.places
        } else {
            var seen = Set<String>()
            places = library.artifacts.compactMap(\.place).filter { place in
                seen.insert(place.id).inserted
            }
        }
        guard scope == .nearMe, let location = locationManager.location else { return places }
        return NearbyPlaceSorter.sort(places, from: location)
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
        LibrarySearchEngine.search(normalizedTerm, in: library.artifacts, index: library.derivedIndex)
    }

    private var recentQueries: [String] {
        recentQueriesRaw.split(separator: "|").map(String.init)
    }

    private var recentDestinations: [OrbitNode] {
        Array(DestinationOrbitBuilder.nodes(from: library.artifacts, mode: .automatic, limit: nil)
            .sorted { $0.saveCount == $1.saveCount ? $0.name < $1.name : $0.saveCount > $1.saveCount }
            .prefix(4))
    }

    private var strongInterests: [InterestPattern] {
        Array(InterestProfileBuilder.build(from: library.artifacts).interests.prefix(4))
    }

    private var savedGuides: [FitGuide] {
        FitGuideLibraryStore.guides(in: guideLibraryJSON)
            .filter { !guideMetadata(for: $0).archived }
            .sorted { guideTitle($0).localizedCaseInsensitiveCompare(guideTitle($1)) == .orderedAscending }
    }

    private var matchingGuides: [FitGuide] {
        guard !normalizedTerm.isEmpty else { return savedGuides }
        return savedGuides.filter { guide in
            [guideTitle(guide), guide.destination.name, guide.destination.country]
                .contains { $0.localizedCaseInsensitiveContains(normalizedTerm) }
                || guide.interests.contains { InterestDisplayName.localized($0).localizedCaseInsensitiveContains(normalizedTerm) }
        }
    }

    private func guideMetadata(for guide: FitGuide) -> FitGuideMetadata {
        FitGuideMetadataStore.metadata(for: guide.id, in: Data(guideMetadataJSON.utf8))
    }

    private func guideTitle(_ guide: FitGuide) -> String {
        guideMetadata(for: guide).customTitle?.trimmedNil ?? guide.collectionTitle
    }

    @ViewBuilder
    private var suggestions: some View {
        if scope == .nearMe {
            Section("Nearby ideas") {
                suggestionButton("Coffee near me", symbol: "cup.and.saucer.fill")
                suggestionButton("Museums near me", symbol: "building.columns.fill")
                suggestionButton("Scenic places near me", symbol: "mountain.2.fill")
            }
        }
        if !recentQueries.isEmpty {
            Section("Recent searches") {
                ForEach(recentQueries.prefix(5), id: \.self) { term in
                    suggestionButton(term, symbol: "clock.arrow.circlepath")
                }
            }
        }
        if scope.shows(.destinations), !recentDestinations.isEmpty {
            Section("Destinations in your orbit") {
                ForEach(recentDestinations) { node in
                    NavigationLink {
                        DestinationLibraryDetailView(node: node, library: library)
                    } label: {
                        Label(node.name, systemImage: "globe.americas.fill")
                    }
                }
            }
        }
        if scope.shows(.interests), !strongInterests.isEmpty {
            Section("Strong interests") {
                ForEach(strongInterests) { pattern in
                    Button {
                        query = InterestDisplayName.localized(pattern.name)
                        scope = .interests
                    } label: {
                        Label(InterestDisplayName.localized(pattern.name), systemImage: "sparkles")
                    }
                }
            }
        }
        if scope.shows(.guides), !savedGuides.isEmpty {
            Section("Saved guides") {
                ForEach(savedGuides.prefix(5)) { guide in
                    guideLink(guide)
                }
            }
        }
        Section("Suggested searches") {
            ForEach(suggestedQueries, id: \.self) { term in
                suggestionButton(term, symbol: "sparkle.magnifyingglass")
            }
        }
    }

    private var suggestedQueries: [String] {
        var suggestions = [String]()
        if let interest = strongInterests.first, let destination = recentDestinations.first {
            suggestions.append("\(InterestDisplayName.localized(interest.name)) in \(destination.name)")
        }
        if let destination = recentDestinations.dropFirst().first {
            suggestions.append("Scenic places in \(destination.name)")
        }
        if suggestions.isEmpty { suggestions.append("Scenic places in Maine") }
        suggestions.append("National parks near me")
        return suggestions
    }

    private func suggestionButton(_ term: String, symbol: String) -> some View {
        Button {
            query = term
            scope = .all
        } label: {
            HStack {
                Label(term, systemImage: symbol)
                Spacer()
                Image(systemName: "arrow.up.left")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func guideLink(_ guide: FitGuide) -> some View {
        NavigationLink {
            FitGuideView(guide: guide, library: library, provider: provider, onKeepGuide: {})
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Label(guideTitle(guide), systemImage: "book.closed.fill")
                    .font(GravitiTypography.headline)
                Text("\(guide.destination.name) · \(FitGuideLibraryStore.memberships(for: guide.id, in: guideLibraryJSON).count) saved")
                    .font(GravitiTypography.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var nearbyLocationStatus: some View {
        if let error = locationManager.errorMessage {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Location needed", systemImage: "location.slash.fill")
                        .font(GravitiTypography.headline)
                    Text(error)
                        .font(GravitiTypography.subheadline)
                        .foregroundStyle(.secondary)
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        Link("Open Settings", destination: settingsURL)
                            .font(GravitiTypography.captionSemibold)
                    }
                }
                .padding(.vertical, 5)
            }
        } else if locationManager.location == nil {
            Section {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Finding your location…")
                }
            }
        }
    }

    private func placeRow(_ place: SavedPlace, includesDistance: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(place.name).font(GravitiTypography.headline)
            if !place.subtitle.isEmpty {
                Text(place.subtitle)
                    .font(GravitiTypography.subheadline)
                    .foregroundStyle(.secondary)
            }
            if includesDistance, let distance = distanceText(to: place) {
                Label(distance, systemImage: "location.fill")
                    .font(GravitiTypography.caption)
                    .foregroundStyle(GravitiColors.signalMint)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func distanceText(to place: SavedPlace) -> String? {
        guard let location = locationManager.location else { return nil }
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        formatter.unitStyle = .short
        formatter.numberFormatter.maximumFractionDigits = 1
        let measurement = Measurement(value: NearbyPlaceSorter.distance(from: location, to: place), unit: UnitLength.meters)
        return String(localized: "\(formatter.string(from: measurement)) away")
    }

    private func savedArtifactRow(_ artifact: Artifact) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(LibrarySearchEngine.title(for: artifact)).font(GravitiTypography.headline).lineLimit(2)
            Text([artifact.effectiveCategory?.displayName, artifact.place?.subtitle]
                .compactMap { $0 }.joined(separator: " · "))
                .font(GravitiTypography.subheadline)
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
            let ordered: [PlaceCandidate]
            if scope == .nearMe, let location = locationManager.location {
                ordered = NearbyPlaceSorter.sort(found, from: location)
            } else {
                ordered = found
            }
            results = Array(ordered.prefix(20))
            remember(term)
            isSearching = false
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = String(localized: "Place search is unavailable. Your saved places are still here.")
            isSearching = false
        }
    }

    private func remember(_ term: String) {
        var values = recentQueries.filter { $0.localizedCaseInsensitiveCompare(term) != .orderedSame }
        values.insert(term, at: 0)
        recentQueriesRaw = values.prefix(8).joined(separator: "|")
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

private enum SearchScope: String, CaseIterable, Identifiable {
    case all, places, destinations, interests, guides, notes, nearMe

    var id: Self { self }
    var title: String {
        switch self {
        case .all: String(localized: "All")
        case .places: String(localized: "Places")
        case .destinations: String(localized: "Destinations")
        case .interests: String(localized: "Interests")
        case .guides: String(localized: "Guides")
        case .notes: String(localized: "Notes")
        case .nearMe: String(localized: "Near me")
        }
    }
    var symbol: String {
        switch self {
        case .all: "square.grid.2x2"
        case .places: "mappin"
        case .destinations: "globe"
        case .interests: "sparkles"
        case .guides: "book.closed"
        case .notes: "note.text"
        case .nearMe: "location.fill"
        }
    }
    var showsRemotePlaces: Bool { self == .all || self == .places || self == .nearMe }
    var showsSavedPlaces: Bool { self == .all || self == .places || self == .nearMe }
    func shows(_ requested: SearchScope) -> Bool { self == .all || self == requested }
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
                            .font(GravitiTypography.subheadline)
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
                                .font(GravitiTypography.headline)
                                .lineLimit(2)
                            if let summary = artifact.effectiveSummary {
                                Text(summary).font(GravitiTypography.subheadline).foregroundStyle(.secondary).lineLimit(2)
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
        .font(GravitiTypography.body)
    }

    private var currentArtifacts: [Artifact] {
        let ids = Set(pattern.artifacts.map(\.id))
        return library.artifacts.filter { ids.contains($0.id) }
    }
}
