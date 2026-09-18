import SwiftUI
import MapKit

struct LibraryView: View {
    @ObservedObject var library: ArtifactLibrary
    @State private var mode: LibraryMode = .saves

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                modePicker

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
        }
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
        let destinations = DestinationOrbitBuilder.nodes(from: library.artifacts, limit: nil)
        if destinations.isEmpty {
            emptyState("No destinations yet", icon: "globe", detail: "Destinations appear as your saves are connected to places.")
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
            emptyState("No places yet", icon: "mappin.and.ellipse", detail: "Search for a place to add it here.")
        } else {
            List(savedPlaces) { place in
                NavigationLink {
                    SavedPlaceDetailView(place: place, artifacts: library.artifacts.filter { $0.place?.id == place.id }, library: library)
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
            emptyState("No places on the map yet", icon: "map", detail: "Saved places will appear here when their locations are known.")
        } else {
            Map(initialPosition: .automatic) {
                ForEach(savedPlaces) { place in
                    Marker(place.name, coordinate: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude))
                }
            }
            .mapStyle(.standard(elevation: .flat))
        }
    }

    private var savedPlaces: [SavedPlace] {
        var seen = Set<String>()
        return library.artifacts.compactMap(\.place).filter { seen.insert($0.id).inserted }
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
        } else if library.artifacts.isEmpty {
            emptyState(
                "No saves yet",
                icon: "square.stack",
                detail: "Save a link or note to start your library."
            )
        } else {
            List(library.artifacts) { artifact in
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
            Image(systemName: artifact.kind == .url ? "link" : "note.text")
                .font(.title3)
                .foregroundStyle(GravitiColors.signalMint)
                .frame(width: 44, height: 44)
                .background(GravitiColors.appBackground, in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
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
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        switch artifact.kind {
        case .url:
            if let title = artifact.originalText, !title.isEmpty { return title }
            guard let source = artifact.sourceURL else { return "Saved link" }
            if MapLinkMetadata.isCollectionLink(source),
               let provider = MapLinkMetadata.provider(for: source) {
                return provider == .apple ? "Apple Maps guide" : "Google Maps list"
            }
            return URLComponents(string: source)?.host ?? source
        case .manual:
            return artifact.originalText?.split(whereSeparator: \.isNewline).first.map(String.init) ?? "Saved note"
        }
    }
}
