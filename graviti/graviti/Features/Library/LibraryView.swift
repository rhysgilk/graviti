import SwiftUI

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
                        emptyState(
                            "No destinations yet",
                            icon: "globe",
                            detail: "Destinations appear as your saves are connected to places."
                        )
                    case .places:
                        emptyState(
                            "No places yet",
                            icon: "mappin.and.ellipse",
                            detail: "Places from your saves will appear here."
                        )
                    case .saves:
                        savesContent
                    case .map:
                        emptyState(
                            "No places on the map yet",
                            icon: "map",
                            detail: "Saved places will appear here when their locations are known."
                        )
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
                    SavedArtifactDetailView(artifact: artifact)
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
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        switch artifact.kind {
        case .url:
            guard let source = artifact.sourceURL else { return "Saved link" }
            return URLComponents(string: source)?.host ?? source
        case .manual:
            return artifact.originalText?.split(whereSeparator: \.isNewline).first.map(String.init) ?? "Saved note"
        }
    }
}
