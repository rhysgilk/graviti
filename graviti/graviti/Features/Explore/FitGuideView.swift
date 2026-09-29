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
    @State private var removedMembership: FitGuideMembership?
    @State private var showingGuideEditor = false
    @AppStorage("fitGuide.metadata.v1") private var metadataJSON = ""
    @AppStorage("fitGuide.library.v1") private var guideLibraryJSON = ""
    @AppStorage("recommendation.outcomes.v1") private var recommendationOutcomesJSON = ""

    private var savedArtifacts: [Artifact] {
        let memberIDs = Set(FitGuideLibraryStore.memberships(for: guide.id, in: guideLibraryJSON).map(\.artifactID))
        let artifacts = library.artifacts.filter { memberIDs.contains($0.id) }
        let order = Dictionary(uniqueKeysWithValues: metadata.orderedArtifactIDs.enumerated().map { ($0.element, $0.offset) })
        return artifacts.sorted {
            (order[$0.id] ?? Int.max, -$0.capturedAt.timeIntervalSince1970) <
                (order[$1.id] ?? Int.max, -$1.capturedAt.timeIntervalSince1970)
        }
    }

    private var metadata: FitGuideMetadata {
        FitGuideMetadataStore.metadata(for: guide.id, in: Data(metadataJSON.utf8))
    }

    private var displayTitle: String { metadata.customTitle?.trimmedNil ?? guide.collectionTitle }

    private var shortlistedArtifacts: [Artifact] {
        let ids = Set(metadata.shortlistPlaceIDs)
        return savedArtifacts.filter { artifact in artifact.place.map { ids.contains($0.id) } ?? false }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    if let coverArtifact {
                        HStack {
                            Spacer()
                            ArtifactThumbnailView(artifact: coverArtifact, size: 132)
                            Spacer()
                        }
                    }
                    Text("Built from your patterns")
                        .font(GravitiTypography.headline)
                    Text(InterestDisplayName.joined(guide.interests))
                        .font(GravitiTypography.subheadline)
                        .foregroundStyle(GravitiColors.signalMint)
                    Text("Suggestions follow live Apple Maps relevance. Open any result in Maps to check current ratings, hours, and details.")
                        .font(GravitiTypography.subheadline)
                        .foregroundStyle(.secondary)
                    if !metadata.note.isEmpty {
                        Text(metadata.note)
                            .font(GravitiTypography.subheadline)
                    }
                    if !guide.interests.isEmpty {
                        Label("\(coveredInterestCount) of \(guide.interests.count) patterns have saved places", systemImage: "chart.bar.fill")
                            .font(GravitiTypography.captionSemibold)
                            .foregroundStyle(GravitiColors.signalMint)
                    }
                }
                .padding(.vertical, 6)
            }

            if !shortlistedArtifacts.isEmpty {
                Section("Shortlist") {
                    ForEach(shortlistedArtifacts) { artifact in
                        savedArtifactRow(artifact, shortlisted: true)
                    }
                }
            }

            if !savedArtifacts.isEmpty {
                Section("Saved in this guide") {
                    ForEach(savedArtifacts) { artifact in
                        savedArtifactRow(artifact, shortlisted: metadata.shortlistPlaceIDs.contains(artifact.place?.id ?? ""))
                    }
                    .onMove(perform: moveSavedArtifacts)
                }
            }

            if isLoading {
                Section {
                    HStack(spacing: 12) {
                        ProgressView()
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Finding places for your patterns…")
                            Text("This uses live Apple Maps data and may take a moment on slower connections. Saved guide places stay available.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
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
                    Button("Try again") { Task { await load() } }
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
                    HStack {
                        Text(notice)
                            .foregroundStyle(GravitiColors.signalMint)
                            .accessibilityAddTraits(.updatesFrequently)
                        Spacer()
                        if removedMembership != nil {
                            Button("Undo") { undoGuideRemoval() }
                                .font(GravitiTypography.captionSemibold)
                        }
                    }
                }
            }
        }
        .font(GravitiTypography.body)
        .scrollContentBackground(.hidden)
        .background(GravitiColors.appBackground)
        .navigationTitle(displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                EditButton()
                Menu {
                    Button { showingGuideEditor = true } label: { Label("Edit guide", systemImage: "pencil") }
                    Button { toggleArchived() } label: {
                        Label(metadata.archived ? "Unarchive" : "Archive", systemImage: "archivebox")
                    }
                    Button { duplicateGuide() } label: {
                        Label("Duplicate guide", systemImage: "plus.square.on.square")
                    }
                    ShareLink(item: exportText) {
                        Label("Share guide", systemImage: "square.and.arrow.up")
                    }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .sheet(isPresented: $showingGuideEditor) {
            FitGuideEditor(title: displayTitle, note: metadata.note) { title, note in
                mutateMetadata {
                    $0.customTitle = title.trimmedNil
                    $0.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        .task(id: guide.id) {
            synchronizeGuideRecord()
            await load()
        }
        .refreshable { await load() }
    }

    private func savedArtifactRow(_ artifact: Artifact, shortlisted: Bool) -> some View {
        NavigationLink {
            SavedArtifactDetailView(artifact: artifact, library: library)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(artifact.place?.name ?? artifact.originalText ?? String(localized: "Saved place"))
                        .font(GravitiTypography.headline)
                    if shortlisted { Image(systemName: "star.fill").foregroundStyle(GravitiColors.signalMint) }
                }
                if let subtitle = artifact.place?.subtitle, !subtitle.isEmpty {
                    Text(subtitle).font(GravitiTypography.subheadline).foregroundStyle(.secondary)
                }
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if artifact.place != nil {
                Button {
                    toggleShortlist(artifact)
                } label: {
                    Label(shortlisted ? "Unshortlist" : "Shortlist", systemImage: shortlisted ? "star.slash" : "star.fill")
                }
                .tint(GravitiColors.iris)
            }
        }
        .contextMenu {
            Button {
                mutateMetadata { $0.coverArtifactID = artifact.id }
            } label: { Label("Use as guide cover", systemImage: "photo") }
            if shortlisted {
                Button { toggleShortlist(artifact) } label: { Label("Remove from shortlist", systemImage: "star.slash") }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                removeFromGuide(artifact)
            } label: { Label("Remove from guide", systemImage: "minus.circle") }
        }
    }

    private func toggleShortlist(_ artifact: Artifact) {
        guard let placeID = artifact.place?.id else { return }
        mutateMetadata { metadata in
            if metadata.shortlistPlaceIDs.contains(placeID) {
                metadata.shortlistPlaceIDs.removeAll { $0 == placeID }
            } else {
                metadata.shortlistPlaceIDs.append(placeID)
            }
        }
    }

    private func moveSavedArtifacts(from offsets: IndexSet, to destination: Int) {
        var ids = savedArtifacts.map(\.id)
        ids.move(fromOffsets: offsets, toOffset: destination)
        mutateMetadata { $0.orderedArtifactIDs = ids }
    }

    private func toggleArchived() { mutateMetadata { $0.archived.toggle() } }

    private var coverArtifact: Artifact? {
        metadata.coverArtifactID.flatMap { id in savedArtifacts.first { $0.id == id } }
    }

    private var coveredInterestCount: Int {
        let covered = Set(FitGuideLibraryStore.memberships(for: guide.id, in: guideLibraryJSON).compactMap(\.interest))
        return guide.interests.filter(covered.contains).count
    }

    private func mutateMetadata(_ mutation: (inout FitGuideMetadata) -> Void) {
        var data = Data(metadataJSON.utf8)
        var value = FitGuideMetadataStore.metadata(for: guide.id, in: data)
        mutation(&value)
        value.updatedAt = .now
        FitGuideMetadataStore.update(value, for: guide.id, in: &data)
        metadataJSON = String(decoding: data, as: UTF8.self)
    }

    private func synchronizeGuideRecord() {
        FitGuideLibraryStore.ensureGuide(guide, in: &guideLibraryJSON)
        FitGuideLibraryStore.migrateLegacyMemberships(for: guide, artifacts: library.artifacts, in: &guideLibraryJSON)
    }

    private func removeFromGuide(_ artifact: Artifact) {
        removedMembership = FitGuideLibraryStore.memberships(for: guide.id, in: guideLibraryJSON)
            .first { $0.artifactID == artifact.id }
        FitGuideLibraryStore.removeMembership(guideID: guide.id, artifactID: artifact.id, from: &guideLibraryJSON)
        notice = String(localized: "Removed from this guide. The source save remains in your Library.")
    }

    private func undoGuideRemoval() {
        guard let removedMembership else { return }
        FitGuideLibraryStore.restoreMembership(removedMembership, in: &guideLibraryJSON)
        self.removedMembership = nil
        notice = String(localized: "Restored to this guide.")
    }

    private func duplicateGuide() {
        removedMembership = nil
        let duplicate = FitGuideLibraryStore.duplicate(guide: guide, in: &guideLibraryJSON)
        var data = Data(metadataJSON.utf8)
        var copy = metadata
        copy.customTitle = String(localized: "\(displayTitle) Copy")
        copy.archived = false
        copy.updatedAt = .now
        FitGuideMetadataStore.update(copy, for: duplicate.id, in: &data)
        metadataJSON = String(decoding: data, as: UTF8.self)
        notice = String(localized: "Created \(copy.customTitle ?? displayTitle).")
    }

    private var exportText: String {
        var lines = [displayTitle]
        if !metadata.note.isEmpty { lines.append(metadata.note) }
        for artifact in savedArtifacts {
            let name = artifact.place?.name ?? artifact.originalText ?? String(localized: "Saved place")
            let star = metadata.shortlistPlaceIDs.contains(artifact.place?.id ?? "") ? "★ " : ""
            lines.append("\(star)\(name)\(artifact.sourceURL.map { " — \($0)" } ?? "")")
        }
        return lines.joined(separator: "\n")
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
            removedMembership = nil
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
            let artifactID = try await library.savePlace(candidate)
            FitGuideLibraryStore.ensureGuide(guide, in: &guideLibraryJSON)
            FitGuideLibraryStore.addMembership(
                guideID: guide.id,
                artifactID: artifactID,
                interest: interest,
                to: &guideLibraryJSON
            )
            onKeepGuide()
            recommendationOutcomesJSON = RecommendationOutcomeStore.recordingSuggestedPlace(
                guide: guide,
                placeName: candidate.place.name,
                in: recommendationOutcomesJSON
            )
            notice = String(localized: "Saved \(candidate.place.name) in \(displayTitle).")
        } catch {
            notice = error.localizedDescription
        }
    }
}

private struct FitGuideEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var title: String
    @State var note: String
    let onSave: (String, String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Guide name", text: $title)
                TextField("Guide note", text: $note, axis: .vertical).lineLimit(3...7)
            }
            .navigationTitle("Edit Fit Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(title, note); dismiss() }
                }
            }
        }
    }
}
