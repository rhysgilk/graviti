import SwiftUI

struct FitGuideLibraryView: View {
    let guides: [FitGuide]
    @ObservedObject var library: ArtifactLibrary
    @State private var query = ""
    @State private var showsArchived = false
    @AppStorage("fitGuide.metadata.v1") private var metadataJSON = ""
    @AppStorage("fitGuide.library.v1") private var guideLibraryJSON = ""
    @AppStorage("fitGuide.sort") private var sortRawValue = FitGuideSort.recentlyUpdated.rawValue

    private var filteredGuides: [FitGuide] {
        let term = normalizedSearchKey(query.trimmingCharacters(in: .whitespacesAndNewlines))
        let visible = guides.filter { metadata(for: $0).archived == showsArchived }
        let searched = term.isEmpty ? visible : visible.filter { guide in
            let searchable = [
                metadata(for: guide).customTitle ?? "",
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
        return searched.sorted(by: sort.areInIncreasingOrder(
            metadata: metadata(for:),
            evidenceCount: evidenceCount(for:)
        ))
    }

    private func normalizedSearchKey(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    var body: some View {
        List {
            if filteredGuides.isEmpty {
                ContentUnavailableView(
                    showsArchived ? "No archived guides" : "No Fit Guides",
                    systemImage: showsArchived ? "archivebox" : "book.closed",
                    description: Text(query.isEmpty ? "Guides appear here when you save a Fit destination." : "Try another search.")
                )
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(FitGuideSort.allCases) { option in
                        Button {
                            sortRawValue = option.rawValue
                        } label: {
                            if option == sort { Label(option.title, systemImage: "checkmark") }
                            else { Text(option.title) }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .accessibilityLabel("Sort Fit Guides")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showsArchived.toggle() } label: {
                    Image(systemName: showsArchived ? "books.vertical.fill" : "archivebox")
                }
                .accessibilityLabel(showsArchived ? "Show active guides" : "Show archived guides")
            }
        }
    }

    private func metadata(for guide: FitGuide) -> FitGuideMetadata {
        FitGuideMetadataStore.metadata(for: guide.id, in: Data(metadataJSON.utf8))
    }

    private var sort: FitGuideSort { FitGuideSort(rawValue: sortRawValue) ?? .recentlyUpdated }

    private func evidenceCount(for guide: FitGuide) -> Int {
        FitGuideLibraryStore.memberships(for: guide.id, in: guideLibraryJSON).count
    }
}

private enum FitGuideSort: String, CaseIterable, Identifiable {
    case recentlyUpdated, alphabetical, mostEvidence
    var id: Self { self }
    var title: String {
        switch self {
        case .recentlyUpdated: String(localized: "Recently updated")
        case .alphabetical: String(localized: "Alphabetical")
        case .mostEvidence: String(localized: "Most evidence")
        }
    }

    func areInIncreasingOrder(
        metadata: @escaping (FitGuide) -> FitGuideMetadata,
        evidenceCount: @escaping (FitGuide) -> Int
    ) -> (FitGuide, FitGuide) -> Bool {
        { lhs, rhs in
            switch self {
            case .recentlyUpdated:
                let left = metadata(lhs).updatedAt
                let right = metadata(rhs).updatedAt
                return left == right ? lhs.destination.name < rhs.destination.name : left > right
            case .alphabetical:
                let left = metadata(lhs).customTitle?.trimmedNil ?? lhs.destination.name
                let right = metadata(rhs).customTitle?.trimmedNil ?? rhs.destination.name
                return left.localizedCaseInsensitiveCompare(right) == .orderedAscending
            case .mostEvidence:
                let left = evidenceCount(lhs)
                let right = evidenceCount(rhs)
                return left == right ? lhs.destination.name < rhs.destination.name : left > right
            }
        }
    }
}

struct FitGuideRow: View {
    let guide: FitGuide
    @ObservedObject var library: ArtifactLibrary
    @AppStorage("fitGuide.metadata.v1") private var metadataJSON = ""
    @AppStorage("fitGuide.library.v1") private var guideLibraryJSON = ""

    private var savedCount: Int {
        let memberIDs = Set(FitGuideLibraryStore.memberships(for: guide.id, in: guideLibraryJSON).map(\.artifactID))
        return library.artifacts.filter { memberIDs.contains($0.id) }.count
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bookmark.fill")
                .foregroundStyle(GravitiColors.signalMint)
            VStack(alignment: .leading, spacing: 3) {
                Text(metadata.customTitle?.trimmedNil ?? guide.destination.name)
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

    private var metadata: FitGuideMetadata {
        FitGuideMetadataStore.metadata(for: guide.id, in: Data(metadataJSON.utf8))
    }
}
