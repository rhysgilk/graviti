import SwiftUI

struct DestinationLibraryDetailView: View {
    let node: OrbitNode
    @ObservedObject var library: ArtifactLibrary

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(node.name)
                        .font(.custom("Sora-SemiBold", size: 26, relativeTo: .title))
                    Text("\(node.saveCount) saved \(node.saveCount == 1 ? "item" : "items") · \(Int(node.gravity)) Gravity")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            if !children.isEmpty {
                Section("Areas") {
                    ForEach(children) { child in
                        NavigationLink {
                            DestinationLibraryDetailView(node: child, library: library)
                        } label: {
                            HStack {
                                Text(child.name)
                                Spacer()
                                Text("\(child.saveCount)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if !places.isEmpty {
                Section("Places") {
                    ForEach(places) { place in
                        NavigationLink {
                            SavedPlaceDetailView(
                                place: place,
                                artifacts: library.artifacts.filter { $0.place?.id == place.id },
                                library: library
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(place.name)
                                Text(place.subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if !matchingArtifacts.isEmpty {
                Section("Saves") {
                    ForEach(matchingArtifacts) { artifact in
                        NavigationLink {
                            SavedArtifactDetailView(artifact: artifact, library: library)
                        } label: {
                            Text(artifact.originalText ?? artifact.sourceURL ?? "Saved item")
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(GravitiColors.appBackground)
        .navigationTitle(node.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var children: [OrbitNode] {
        DestinationOrbitBuilder.children(of: node, from: library.artifacts, limit: nil)
    }

    private var matchingArtifacts: [Artifact] {
        DestinationOrbitBuilder.artifacts(for: node, from: library.artifacts)
    }

    private var places: [SavedPlace] {
        var seen = Set<String>()
        return matchingArtifacts.compactMap(\.place).filter { seen.insert($0.id).inserted }
    }
}
