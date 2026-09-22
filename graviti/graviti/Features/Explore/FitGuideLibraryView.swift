import SwiftUI

struct FitGuideLibraryView: View {
    let guides: [FitGuide]
    @ObservedObject var library: ArtifactLibrary
    @State private var query = ""

    private var filteredGuides: [FitGuide] {
        let term = normalizedSearchKey(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !term.isEmpty else { return guides }
        return guides.filter { guide in
            let searchable = [
                guide.destination.name,
                guide.destination.country,
                guide.interests.joined(separator: " "),
                library.artifacts
                    .filter(guide.contains)
                    .compactMap { $0.place?.name ?? $0.originalText }
                    .joined(separator: " ")
            ]
            .joined(separator: " ")
            let normalized = normalizedSearchKey(searchable)
            return normalized.contains(term)
        }
    }

    private func normalizedSearchKey(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    var body: some View {
        List {
            if filteredGuides.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                Section {
                    ForEach(filteredGuides) { guide in
                        NavigationLink {
                            FitGuideView(
                                guide: guide,
                                library: library,
                                provider: MapKitPlaceSearchProvider(),
                                onKeepGuide: {}
                            )
                        } label: {
                            FitGuideRow(guide: guide, library: library)
                        }
                    }
                } footer: {
                    Text("Fit Guides stay here even when their destinations are no longer in your current recommendations.")
                }
            }
        }
        .font(GravitiTypography.body)
        .scrollContentBackground(.hidden)
        .background(GravitiColors.appBackground)
        .navigationTitle("Fit Guides")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Search guides and saved places")
    }
}

struct FitGuideRow: View {
    let guide: FitGuide
    @ObservedObject var library: ArtifactLibrary

    private var savedCount: Int {
        library.artifacts.filter(guide.contains).count
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bookmark.fill")
                .foregroundStyle(GravitiColors.signalMint)
            VStack(alignment: .leading, spacing: 3) {
                Text(guide.destination.name)
                    .font(GravitiTypography.headline)
                Text("\(guide.destination.country) · \(GravitiCopy.savedItems(savedCount))")
                    .font(GravitiTypography.caption)
                    .foregroundStyle(.secondary)
                Text(InterestDisplayName.joined(guide.interests))
                    .font(GravitiTypography.caption)
                    .foregroundStyle(GravitiColors.signalMint)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
    }
}
