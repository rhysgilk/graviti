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

            if !profile.interests.isEmpty || !profile.categories.isEmpty {
                Section("What pulls you here") {
                    VStack(alignment: .leading, spacing: 12) {
                        if !profile.interests.isEmpty {
                            Text(profile.interests.prefix(6).map(\.name).joined(separator: " · "))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)
                        }

                        if !profile.categories.isEmpty {
                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: 14) { categorySummary }
                                VStack(alignment: .leading, spacing: 8) { categorySummary }
                            }
                            .font(.caption)
                            .foregroundStyle(GravitiColors.signalMint)
                        }
                    }
                    .padding(.vertical, 6)
                    .accessibilityElement(children: .combine)
                }
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
                            DestinationArtifactRow(artifact: artifact)
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

    private var profile: InterestProfile {
        InterestProfileBuilder.build(from: matchingArtifacts)
    }

    @ViewBuilder
    private var categorySummary: some View {
        ForEach(profile.categories.prefix(3)) { pattern in
            Label("\(pattern.saveCount) \(pattern.category.displayName)", systemImage: "circle.fill")
                .labelStyle(.titleAndIcon)
        }
    }
}

private struct DestinationArtifactRow: View {
    let artifact: Artifact

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .lineLimit(2)

                if let summary = artifact.effectiveSummary, summary != title {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let category = artifact.effectiveCategory {
                    Text(category.displayName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(GravitiColors.signalMint)
                } else if !artifact.effectiveInterests.isEmpty {
                    Text(artifact.effectiveInterests.prefix(3).joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let mediaKey = artifact.mediaKey {
            MediaPreviewView(mediaKey: mediaKey, maximumPixelSize: 180, minimumHeight: 58)
                .frame(width: 58, height: 58)
                .background(GravitiColors.deepInk)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            Image(systemName: artifact.kind == .url ? "link" : "note.text")
                .font(.title3)
                .foregroundStyle(GravitiColors.signalMint)
                .frame(width: 58, height: 58)
                .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var title: String {
        artifact.originalText ?? artifact.userNote ?? artifact.place?.name ?? artifact.sourceURL ?? String(localized: "Saved item")
    }
}
