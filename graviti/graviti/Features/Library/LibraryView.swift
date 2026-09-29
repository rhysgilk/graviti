import SwiftUI
import MapKit
import UniformTypeIdentifiers

struct LibraryView: View {
    @ObservedObject var library: ArtifactLibrary
    @AppStorage("library.mode") private var modeRawValue = LibraryMode.destinations.rawValue
    @AppStorage("explore.region") private var exploreRegionRaw = RecommendationRegion.anywhere.rawValue
    @AppStorage("explore.preferredInterests") private var preferredInterestsRaw = ""
    @AppStorage("explore.avoidedInterests") private var avoidedInterestsRaw = ""
    @AppStorage("explore.savedDestinations") private var savedDestinationsRaw = ""
    @AppStorage("explore.excludedDestinations") private var excludedDestinationsRaw = ""
    @AppStorage("explore.visitedLikedDestinations") private var visitedLikedDestinationsRaw = ""
    @AppStorage("explore.visitedNotFitDestinations") private var visitedNotFitDestinationsRaw = ""
    @AppStorage("fitGuide.library.v1") private var fitGuideLibraryJSON = ""
    @AppStorage("fitGuide.metadata.v1") private var fitGuideMetadataJSON = ""
    @AppStorage("recommendation.feedback.v1") private var recommendationFeedbackJSON = ""
    @AppStorage("recommendation.outcomes.v1") private var recommendationOutcomesJSON = ""
    @AppStorage("recommendation.prompts.v1") private var recommendationPromptsJSON = ""
    @AppStorage("import.attempts.v1") private var importAttemptsJSON = ""
    @State private var selectedMapPlace: SavedPlace?
    @State private var query = ""
    @State private var showsNeedsReviewOnly = false
    @State private var isSelectingPlaces = false
    @State private var selectedPlaceIDs: Set<String> = []
    @State private var showingBulkRemoveConfirmation = false
    @State private var isRemovingPlaces = false
    @State private var placeActionError: String?
    @State private var isSelectingSaves = false
    @State private var selectedArtifactIDs: Set<UUID> = []
    @State private var showingBulkDeleteConfirmation = false
    @State private var isDeletingSaves = false
    @State private var saveActionError: String?
    @State private var selectionRowFrames: [String: CGRect] = [:]
    @State private var dragSelectionAdds: Bool?
    @State private var dragSelectionStartY: CGFloat?
    @State private var dragVisitedSelectionKeys: Set<String> = []
    @State private var rowActionError: LibraryActionError?
    @State private var backupDocument = LibraryBackupDocument()
    @State private var isExportingBackup = false
    @State private var isImportingBackup = false
    @State private var backupStatus: LibraryBackupStatus?
    @State private var showingDataPrivacy = false
    @State private var smartFilter: LibrarySmartFilter = .all
    @AppStorage("library.savedFilters.v1") private var savedFiltersJSON = ""
    @AppStorage("library.selectedSavedFilter") private var selectedSavedFilterRaw = ""
    @State private var showingSavedFilters = false
    @AppStorage("library.sort.destinations") private var destinationSortRawValue = LibrarySort.gravity.rawValue
    @AppStorage("library.sort.places") private var placeSortRawValue = LibrarySort.recentlySaved.rawValue
    @AppStorage("library.sort.saves") private var saveSortRawValue = LibrarySort.recentlySaved.rawValue
    @StateObject private var locationManager = SearchLocationManager()
    @State private var pendingUndo: PendingLibraryUndo?
    @State private var undoExpirationTask: Task<Void, Never>?
    @State private var showingCompletenessReview = false

    private var mode: LibraryMode {
        get { LibraryMode(rawValue: modeRawValue) ?? .destinations }
        nonmutating set { modeRawValue = newValue.rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                modePicker

                if mode != .map && mode != .inbox {
                    smartFilterPicker
                }

                if needsReviewCount > 0 || showsNeedsReviewOnly {
                    reviewFilter
                }

                if incompleteCount > 0, mode != .inbox {
                    completenessReviewButton
                }

                if !repeatedPlaceGroups.isEmpty {
                    repeatedPlacesLink
                }

                Group {
                    if library.artifacts.isEmpty, let error = library.loadError {
                        libraryLoadError(error)
                    } else {
                        switch mode {
                        case .destinations:
                            destinationsContent
                        case .places:
                            placesContent
                        case .saves:
                            savesContent
                        case .map:
                            mapContent
                        case .inbox:
                            ImportInboxView(library: library)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(GravitiColors.appBackground)
            .navigationTitle("Library")
            .toolbar {
                if mode == .places, !savedPlaces.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(isSelectingPlaces ? "Done" : "Select") {
                            isSelectingPlaces.toggle()
                            if !isSelectingPlaces { selectedPlaceIDs.removeAll() }
                        }
                    }
                } else if mode == .saves, !filteredArtifacts.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(isSelectingSaves ? "Done" : "Select") {
                            isSelectingSaves.toggle()
                            if !isSelectingSaves { selectedArtifactIDs.removeAll() }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if !availableSorts.isEmpty {
                            Menu("Sort") {
                                ForEach(availableSorts) { option in
                                    Button {
                                        setSort(option)
                                        if option == .distance { locationManager.requestLocation() }
                                    } label: {
                                        if sort == option { Label(option.title, systemImage: "checkmark") }
                                        else { Text(option.title) }
                                    }
                                }
                            }
                            Divider()
                        }
                        Button {
                            exportBackup()
                        } label: {
                            Label("Export backup", systemImage: "square.and.arrow.up")
                        }
                        Button {
                            isImportingBackup = true
                        } label: {
                            Label("Restore backup", systemImage: "square.and.arrow.down")
                        }
                        Divider()
                        Button {
                            showingDataPrivacy = true
                        } label: {
                            Label("Data & privacy", systemImage: "lock.shield")
                        }
                        Button {
                            showingSavedFilters = true
                        } label: {
                            Label("Manage saved views", systemImage: "line.3.horizontal.decrease.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Library actions")
                }
            }
            .searchable(text: $query, prompt: "Places, interests, and saves")
            .onChange(of: query) { _, _ in
                if let selectedMapPlace, !savedPlaces.contains(where: { $0.id == selectedMapPlace.id }) {
                    self.selectedMapPlace = nil
                }
            }
            .onChange(of: needsReviewCount) { _, count in
                if count == 0 { showsNeedsReviewOnly = false }
            }
            .onChange(of: mode) { _, newMode in
                if newMode != .places {
                    isSelectingPlaces = false
                    selectedPlaceIDs.removeAll()
                }
                if newMode != .saves {
                    isSelectingSaves = false
                    selectedArtifactIDs.removeAll()
                }
            }
            .safeAreaInset(edge: .bottom) {
                if mode == .places, isSelectingPlaces {
                    bulkPlaceActions
                } else if mode == .saves, isSelectingSaves {
                    bulkSaveActions
                } else if let pendingUndo {
                    undoBar(pendingUndo)
                }
            }
            .confirmationDialog(
                GravitiCopy.removeSelectedPlacesQuestion(selectedPlaceIDs.count),
                isPresented: $showingBulkRemoveConfirmation,
                titleVisibility: .visible
            ) {
                Button("Remove places", role: .destructive) { removeSelectedPlaces() }
            } message: {
                Text("The associated saves stay in your Library and can be matched to places again later.")
            }
            .confirmationDialog(
                GravitiCopy.deleteSelectedSavesQuestion(selectedArtifactIDs.count),
                isPresented: $showingBulkDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete saved items", role: .destructive) { deleteSelectedSaves() }
            } message: {
                Text("This permanently removes the selected items and updates their places, Gravity, and interest signals.")
            }
            .fileExporter(
                isPresented: $isExportingBackup,
                document: backupDocument,
                contentType: .json,
                defaultFilename: "Graviti Backup"
            ) { result in
                switch result {
                case .success:
                    backupStatus = LibraryBackupStatus(message: "Your Graviti backup was exported.")
                case .failure(let error):
                    backupStatus = LibraryBackupStatus(message: error.localizedDescription)
                }
            }
            .fileImporter(isPresented: $isImportingBackup, allowedContentTypes: [.json]) { result in
                restoreBackup(result)
            }
            .sheet(isPresented: $showingDataPrivacy) {
                DataPrivacyView(library: library)
            }
            .sheet(isPresented: $showingCompletenessReview) {
                CompletenessReviewView(library: library)
            }
            .sheet(isPresented: $showingSavedFilters) {
                SavedLibraryFiltersView(filtersJSON: $savedFiltersJSON) { id in
                    selectedSavedFilterRaw = id.uuidString
                    smartFilter = .all
                }
            }
            .alert(item: $backupStatus) { status in
                Alert(title: Text("Library backup"), message: Text(status.message), dismissButton: .default(Text("OK")))
            }
            .alert(item: $rowActionError) { error in
                Alert(title: Text("Library action failed"), message: Text(error.message), dismissButton: .default(Text("OK")))
            }
            .onDisappear { finalizePendingUndo() }
        }
        .font(GravitiTypography.body)
    }

    private func exportBackup() {
        do {
            backupDocument = LibraryBackupDocument(data: try library.backupData(preferences: backupPreferences))
            isExportingBackup = true
        } catch {
            backupStatus = LibraryBackupStatus(message: error.localizedDescription)
        }
    }

    private func restoreBackup(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            Task {
                do {
                    let summary = try await library.restoreBackup(data)
                    if let preferences = summary.preferences {
                        restore(preferences)
                    }
                    let itemSummary = GravitiCopy.restoreSummary(
                        imported: summary.imported,
                        duplicates: summary.duplicates
                    )
                    backupStatus = LibraryBackupStatus(
                        message: summary.preferences == nil
                            ? itemSummary
                            : "\(itemSummary) \(String(localized: "Your preferences, guides, and local activity were restored."))"
                    )
                } catch {
                    backupStatus = LibraryBackupStatus(message: error.localizedDescription)
                }
            }
        } catch {
            backupStatus = LibraryBackupStatus(message: error.localizedDescription)
        }
    }

    private var backupPreferences: LibraryBackupPreferences {
        LibraryBackupPreferences(
            recommendationRegion: (RecommendationRegion(rawValue: exploreRegionRaw) ?? .anywhere).rawValue,
            preferredInterests: Self.decodePreferenceSet(preferredInterestsRaw),
            avoidedInterests: Self.decodePreferenceSet(avoidedInterestsRaw),
            savedDestinationIDs: Self.decodePreferenceSet(savedDestinationsRaw),
            excludedDestinationIDs: Self.decodePreferenceSet(excludedDestinationsRaw),
            visitedLikedDestinationIDs: Self.decodePreferenceSet(visitedLikedDestinationsRaw),
            visitedNotFitDestinationIDs: Self.decodePreferenceSet(visitedNotFitDestinationsRaw),
            fitGuideLibraryJSON: fitGuideLibraryJSON,
            fitGuideMetadataJSON: fitGuideMetadataJSON,
            recommendationFeedbackJSON: recommendationFeedbackJSON,
            recommendationOutcomesJSON: recommendationOutcomesJSON,
            recommendationPromptsJSON: recommendationPromptsJSON,
            importAttemptsJSON: importAttemptsJSON,
            savedLibraryFiltersJSON: savedFiltersJSON
        )
    }

    private func restore(_ preferences: LibraryBackupPreferences) {
        exploreRegionRaw = preferences.recommendationRegion
        preferredInterestsRaw = Self.encodePreferenceSet(preferences.preferredInterests)
        avoidedInterestsRaw = Self.encodePreferenceSet(preferences.avoidedInterests)
        savedDestinationsRaw = Self.encodePreferenceSet(preferences.savedDestinationIDs)
        excludedDestinationsRaw = Self.encodePreferenceSet(preferences.excludedDestinationIDs)
        visitedLikedDestinationsRaw = Self.encodePreferenceSet(preferences.visitedLikedDestinationIDs)
        visitedNotFitDestinationsRaw = Self.encodePreferenceSet(preferences.visitedNotFitDestinationIDs)
        fitGuideLibraryJSON = preferences.fitGuideLibraryJSON
        fitGuideMetadataJSON = preferences.fitGuideMetadataJSON
        recommendationFeedbackJSON = preferences.recommendationFeedbackJSON
        recommendationOutcomesJSON = preferences.recommendationOutcomesJSON
        recommendationPromptsJSON = preferences.recommendationPromptsJSON
        importAttemptsJSON = preferences.importAttemptsJSON
        savedFiltersJSON = preferences.savedLibraryFiltersJSON
    }

    private static func decodePreferenceSet(_ raw: String) -> [String] {
        raw.split(separator: "|").map(String.init)
    }

    private static func encodePreferenceSet(_ values: [String]) -> String {
        values.sorted().joined(separator: "|")
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
                    .font(GravitiTypography.captionSemibold)
                    .frame(minWidth: 28, minHeight: 28)
                    .background(.white.opacity(0.12), in: Circle())
                Image(systemName: showsNeedsReviewOnly ? "checkmark.circle.fill" : "chevron.forward")
            }
            .font(GravitiTypography.subheadline)
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

    private var completenessReviewButton: some View {
        Button { showingCompletenessReview = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "wand.and.stars")
                    .foregroundStyle(GravitiColors.signalMint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Complete \(min(incompleteCount, 6)) saves")
                        .font(GravitiTypography.subheadlineSemibold)
                    Text("Add the details only you know")
                        .font(GravitiTypography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.forward").foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 58)
            .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private var repeatedPlacesLink: some View {
        NavigationLink {
            RepeatedPlacesView(groups: repeatedPlaceGroups, library: library)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "square.on.square")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Repeated places")
                        .fontWeight(.semibold)
                    Text(GravitiCopy.repeatedPlaces(repeatedPlaceGroups.count))
                        .font(GravitiTypography.caption)
                        .foregroundStyle(.white.opacity(0.62))
                }
                Spacer()
                Image(systemName: "chevron.forward")
            }
            .font(GravitiTypography.subheadline)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(minHeight: 58)
            .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private var modePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LibraryMode.allCases) { option in
                    Button {
                        mode = option
                    } label: {
                        Text(option.title)
                            .font(GravitiTypography.subheadlineSemibold)
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

    private var smartFilterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LibrarySmartFilter.allCases) { filter in
                    Button {
                        smartFilter = filter
                        selectedSavedFilterRaw = ""
                    } label: {
                        Label(filter.title, systemImage: filter.symbol)
                            .font(GravitiTypography.captionSemibold)
                            .foregroundStyle(selectedSavedFilter == nil && smartFilter == filter ? .white : .white.opacity(0.62))
                            .padding(.horizontal, 12)
                            .frame(minHeight: 36)
                            .background(selectedSavedFilter == nil && smartFilter == filter ? GravitiColors.iris.opacity(0.82) : GravitiColors.deepInk, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedSavedFilter == nil && smartFilter == filter ? .isSelected : [])
                }
                ForEach(savedFilters) { filter in
                    Button {
                        selectedSavedFilterRaw = filter.id.uuidString
                        smartFilter = .all
                    } label: {
                        Label(filter.name, systemImage: "line.3.horizontal.decrease.circle.fill")
                            .font(GravitiTypography.captionSemibold)
                            .foregroundStyle(selectedSavedFilter?.id == filter.id ? .white : .white.opacity(0.62))
                            .padding(.horizontal, 12)
                            .frame(minHeight: 36)
                            .background(selectedSavedFilter?.id == filter.id ? GravitiColors.iris.opacity(0.82) : GravitiColors.deepInk, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Button { showingSavedFilters = true } label: {
                    Label("Save view", systemImage: "plus")
                        .font(GravitiTypography.captionSemibold)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 36)
                        .background(GravitiColors.deepInk, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
    }

    @ViewBuilder
    private var destinationsContent: some View {
        let destinations = sortedDestinations(DestinationOrbitBuilder.nodes(from: filteredArtifacts, limit: nil))
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
                        Text(node.name).font(GravitiTypography.headline)
                        Text("\(node.level.displayName) · \(GravitiCopy.savedItems(node.saveCount))")
                            .font(GravitiTypography.subheadline)
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
        } else if isSelectingPlaces {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(savedPlaces) { place in
                        Button {
                            if selectedPlaceIDs.contains(place.id) {
                                selectedPlaceIDs.remove(place.id)
                            } else {
                                selectedPlaceIDs.insert(place.id)
                            }
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: selectedPlaceIDs.contains(place.id) ? "checkmark.circle.fill" : "circle")
                                    .font(GravitiTypography.title3)
                                    .foregroundStyle(selectedPlaceIDs.contains(place.id) ? GravitiColors.signalMint : .secondary)
                                placeLabel(place)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityValue(selectedPlaceIDs.contains(place.id) ? "Selected" : "Not selected")
                        .padding(.horizontal, 20)
                        .background(selectionFrame(for: "place:\(place.id)"))
                        Divider().padding(.leading, 20)
                    }
                }
            }
            .coordinateSpace(name: "librarySelectionList")
            .onPreferenceChange(LibrarySelectionFramePreferenceKey.self) { selectionRowFrames = $0 }
            .highPriorityGesture(selectionDragGesture(for: .places))
        } else {
            List(savedPlaces) { place in
                NavigationLink {
                    SavedPlaceDetailView(place: place, library: library)
                } label: {
                    placeLabel(place)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        removePlace(place.id)
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
                .listRowBackground(GravitiColors.deepInk)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private func placeLabel(_ place: SavedPlace) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(place.name).font(GravitiTypography.headline)
            Text(place.subtitle).font(GravitiTypography.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }

    private var bulkPlaceActions: some View {
        VStack(spacing: 8) {
            if let placeActionError {
                Text(placeActionError)
                    .font(GravitiTypography.caption)
                    .foregroundStyle(GravitiColors.opportunityCoral)
            }
            Button(role: .destructive) {
                showingBulkRemoveConfirmation = true
            } label: {
                Label(
                    selectedPlaceIDs.isEmpty
                        ? String(localized: "Select places to remove")
                        : GravitiCopy.removeSelectedPlacesLabel(selectedPlaceIDs.count),
                    systemImage: "trash"
                )
                .font(GravitiTypography.subheadlineSemibold)
                .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(GravitiColors.opportunityCoral)
            .disabled(selectedPlaceIDs.isEmpty || isRemovingPlaces)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private func removeSelectedPlaces() {
        let ids = selectedPlaceIDs
        guard !ids.isEmpty else { return }
        isRemovingPlaces = true
        placeActionError = nil
        Task {
            do {
                try await library.removePlacesFromLibrary(ids)
                selectedPlaceIDs.removeAll()
                isSelectingPlaces = false
            } catch {
                placeActionError = error.localizedDescription
            }
            isRemovingPlaces = false
        }
    }

    private var bulkSaveActions: some View {
        VStack(spacing: 8) {
            if let saveActionError {
                Text(saveActionError)
                    .font(GravitiTypography.caption)
                    .foregroundStyle(GravitiColors.opportunityCoral)
            }
            Button(role: .destructive) {
                showingBulkDeleteConfirmation = true
            } label: {
                Label(
                    selectedArtifactIDs.isEmpty
                        ? String(localized: "Select saves to delete")
                        : GravitiCopy.deleteSelectedSavesLabel(selectedArtifactIDs.count),
                    systemImage: "trash"
                )
                .font(GravitiTypography.subheadlineSemibold)
                .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(GravitiColors.opportunityCoral)
            .disabled(selectedArtifactIDs.isEmpty || isDeletingSaves)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private func deleteSelectedSaves() {
        let ids = selectedArtifactIDs
        guard !ids.isEmpty else { return }
        isDeletingSaves = true
        saveActionError = nil
        Task {
            do {
                try await library.deleteArtifacts(ids)
                selectedArtifactIDs.removeAll()
                isSelectingSaves = false
            } catch {
                saveActionError = error.localizedDescription
                selectedArtifactIDs.formIntersection(Set(library.artifacts.map(\.id)))
            }
            isDeletingSaves = false
        }
    }

    private func removePlace(_ id: String) {
        let title = library.artifacts.first(where: { $0.place?.id == id })?.place?.name ?? String(localized: "Place")
        Task {
            do {
                finalizePendingUndo()
                let originals = try await library.stagePlaceRemoval(id)
                guard !originals.isEmpty else { return }
                scheduleUndo(PendingLibraryUndo(message: String(localized: "Removed \(title)"), payload: .place(originals)))
            } catch {
                rowActionError = LibraryActionError(message: error.localizedDescription)
            }
        }
    }

    private func deleteSave(_ id: UUID) {
        let title = library.artifacts.first(where: { $0.id == id })?.libraryTitle ?? String(localized: "Saved item")
        Task {
            do {
                finalizePendingUndo()
                if let artifact = try await library.stageArtifactDeletion(id) {
                    scheduleUndo(PendingLibraryUndo(message: String(localized: "Deleted \(title)"), payload: .artifact(artifact)))
                }
            } catch {
                rowActionError = LibraryActionError(message: error.localizedDescription)
            }
        }
    }

    private func undoBar(_ pending: PendingLibraryUndo) -> some View {
        HStack(spacing: 12) {
            Text(pending.message)
                .font(GravitiTypography.subheadline)
                .lineLimit(1)
            Spacer()
            Button("Undo") { undo(pending) }
                .font(GravitiTypography.subheadlineSemibold)
                .foregroundStyle(GravitiColors.signalMint)
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 52)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 15))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
    }

    private func scheduleUndo(_ pending: PendingLibraryUndo) {
        undoExpirationTask?.cancel()
        pendingUndo = pending
        undoExpirationTask = Task {
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled, pendingUndo?.id == pending.id else { return }
            finalizePendingUndo()
        }
    }

    private func undo(_ pending: PendingLibraryUndo) {
        undoExpirationTask?.cancel()
        undoExpirationTask = nil
        pendingUndo = nil
        Task {
            do {
                switch pending.payload {
                case .artifact(let artifact): try await library.restoreArtifactDeletion(artifact)
                case .place(let originals): try await library.restorePlaceRemoval(originals)
                }
            } catch {
                rowActionError = LibraryActionError(message: error.localizedDescription)
            }
        }
    }

    private func finalizePendingUndo() {
        undoExpirationTask?.cancel()
        undoExpirationTask = nil
        guard let pending = pendingUndo else { return }
        pendingUndo = nil
        if case .artifact(let artifact) = pending.payload {
            library.finalizeArtifactDeletion(artifact)
        }
    }

    private func selectionFrame(for key: String) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: LibrarySelectionFramePreferenceKey.self,
                value: [key: proxy.frame(in: .named("librarySelectionList"))]
            )
        }
    }

    private func selectionDragGesture(for kind: LibrarySelectionKind) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .named("librarySelectionList"))
            .onChanged { value in
                guard (kind == .places && isSelectingPlaces) || (kind == .saves && isSelectingSaves) else { return }
                if dragSelectionAdds == nil {
                    guard let startKey = selectionKey(at: value.startLocation, kind: kind) else { return }
                    dragSelectionAdds = !selectionContains(startKey, kind: kind)
                    dragSelectionStartY = value.startLocation.y
                    dragVisitedSelectionKeys.insert(startKey)
                    setSelection(startKey, kind: kind, selected: dragSelectionAdds == true)
                }
                guard let adds = dragSelectionAdds, let startY = dragSelectionStartY else { return }
                let bounds = min(startY, value.location.y)...max(startY, value.location.y)
                let crossedKeys = selectionRowFrames
                    .filter { key, frame in key.hasPrefix(kind.keyPrefix) && bounds.contains(frame.midY) }
                    .sorted { $0.value.midY < $1.value.midY }
                    .map(\.key)
                for key in crossedKeys where dragVisitedSelectionKeys.insert(key).inserted {
                    setSelection(key, kind: kind, selected: adds)
                }
            }
            .onEnded { _ in
                dragSelectionAdds = nil
                dragSelectionStartY = nil
                dragVisitedSelectionKeys.removeAll()
            }
    }

    private func selectionKey(at point: CGPoint, kind: LibrarySelectionKind) -> String? {
        selectionRowFrames.first { key, frame in
            key.hasPrefix(kind.keyPrefix) && frame.contains(point)
        }?.key
    }

    private func selectionContains(_ key: String, kind: LibrarySelectionKind) -> Bool {
        switch kind {
        case .places:
            return selectedPlaceIDs.contains(String(key.dropFirst(kind.keyPrefix.count)))
        case .saves:
            guard let id = UUID(uuidString: String(key.dropFirst(kind.keyPrefix.count))) else { return false }
            return selectedArtifactIDs.contains(id)
        }
    }

    private func setSelection(_ key: String, kind: LibrarySelectionKind, selected: Bool) {
        switch kind {
        case .places:
            let id = String(key.dropFirst(kind.keyPrefix.count))
            if selected { selectedPlaceIDs.insert(id) } else { selectedPlaceIDs.remove(id) }
        case .saves:
            guard let id = UUID(uuidString: String(key.dropFirst(kind.keyPrefix.count))) else { return }
            if selected { selectedArtifactIDs.insert(id) } else { selectedArtifactIDs.remove(id) }
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
                    let category = PlaceMapCategoryStyle.category(for: place.id, in: filteredArtifacts)
                    Marker(
                        place.name,
                        systemImage: category.mapSymbolName,
                        coordinate: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
                    )
                    .tint(category.mapTint)
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
        let places = filteredArtifacts.compactMap(\.place).filter { seen.insert($0.id).inserted }
        return places.sorted(by: placeSort)
    }

    private var filteredArtifacts: [Artifact] {
        let reviewFiltered = showsNeedsReviewOnly
            ? library.artifacts.filter(\.needsPlaceReview)
            : library.artifacts
        let smartFiltered = reviewFiltered.filter { artifact in
            selectedSavedFilter?.matches(artifact) ?? smartFilter.matches(artifact)
        }
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let searched = term.isEmpty ? smartFiltered : smartFiltered.filter {
            $0.librarySearchText.localizedCaseInsensitiveContains(term)
        }
        guard mode == .saves else { return searched }
        if sort == .distance, let location = locationManager.location {
            return searched.sorted { lhs, rhs in
                guard let left = lhs.place else { return false }
                guard let right = rhs.place else { return true }
                return NearbyPlaceSorter.distance(from: location, to: left) < NearbyPlaceSorter.distance(from: location, to: right)
            }
        }
        if sort == .recentlyUpdated {
            return searched.sorted { latestUpdate([$0]) > latestUpdate([$1]) }
        }
        return searched.sorted(by: sort.areInIncreasingOrder)
    }

    private var sort: LibrarySort {
        let raw: String
        switch mode {
        case .destinations: raw = destinationSortRawValue
        case .places: raw = placeSortRawValue
        case .saves: raw = saveSortRawValue
        case .map, .inbox: return .recentlySaved
        }
        let selected = LibrarySort(rawValue: raw) ?? .recentlySaved
        return availableSorts.contains(selected) ? selected : (availableSorts.first ?? .recentlySaved)
    }

    private var availableSorts: [LibrarySort] {
        switch mode {
        case .destinations: [.gravity, .recentlySaved, .alphabetical, .mostEvidence]
        case .places: [.recentlySaved, .alphabetical, .distance, .mostEvidence, .leastComplete, .recentlyUpdated]
        case .saves: [.recentlySaved, .alphabetical, .distance, .mostEvidence, .leastComplete, .recentlyUpdated]
        case .map, .inbox: []
        }
    }

    private func setSort(_ value: LibrarySort) {
        switch mode {
        case .destinations: destinationSortRawValue = value.rawValue
        case .places: placeSortRawValue = value.rawValue
        case .saves: saveSortRawValue = value.rawValue
        case .map, .inbox: break
        }
    }

    private func placeSort(_ lhs: SavedPlace, _ rhs: SavedPlace) -> Bool {
        let lhsArtifacts = filteredArtifacts.filter { $0.place?.id == lhs.id }
        let rhsArtifacts = filteredArtifacts.filter { $0.place?.id == rhs.id }
        switch sort {
        case .alphabetical:
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        case .distance:
            guard let location = locationManager.location else {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return NearbyPlaceSorter.distance(from: location, to: lhs) < NearbyPlaceSorter.distance(from: location, to: rhs)
        case .mostEvidence:
            return evidenceScore(lhsArtifacts) == evidenceScore(rhsArtifacts)
                ? lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                : evidenceScore(lhsArtifacts) > evidenceScore(rhsArtifacts)
        case .leastComplete:
            return averageCompleteness(lhsArtifacts) == averageCompleteness(rhsArtifacts)
                ? lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                : averageCompleteness(lhsArtifacts) < averageCompleteness(rhsArtifacts)
        case .recentlyUpdated:
            return latestUpdate(lhsArtifacts) > latestUpdate(rhsArtifacts)
        case .recentlySaved, .gravity, .fit:
            return (lhsArtifacts.map(\.capturedAt).max() ?? .distantPast) > (rhsArtifacts.map(\.capturedAt).max() ?? .distantPast)
        }
    }

    private func sortedDestinations(_ nodes: [OrbitNode]) -> [OrbitNode] {
        nodes.sorted { lhs, rhs in
            let lhsArtifacts = DestinationOrbitBuilder.artifacts(for: lhs, from: filteredArtifacts)
            let rhsArtifacts = DestinationOrbitBuilder.artifacts(for: rhs, from: filteredArtifacts)
            switch sort {
            case .alphabetical:
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            case .mostEvidence:
                return evidenceScore(lhsArtifacts) == evidenceScore(rhsArtifacts)
                    ? OrbitNode.ranksBefore(lhs, rhs)
                    : evidenceScore(lhsArtifacts) > evidenceScore(rhsArtifacts)
            case .recentlySaved, .recentlyUpdated:
                return latestUpdate(lhsArtifacts) == latestUpdate(rhsArtifacts)
                    ? OrbitNode.ranksBefore(lhs, rhs)
                    : latestUpdate(lhsArtifacts) > latestUpdate(rhsArtifacts)
            case .gravity, .fit, .distance, .leastComplete:
                return OrbitNode.ranksBefore(lhs, rhs)
            }
        }
    }

    private func evidenceScore(_ artifacts: [Artifact]) -> Int {
        artifacts.reduce(0) { score, artifact in
            score + artifact.effectiveInterests.count
                + (artifact.userNote?.trimmedNil == nil ? 0 : 2)
                + (artifact.effectiveSummary?.trimmedNil == nil ? 0 : 1)
                + (artifact.place == nil ? 0 : 1)
        }
    }

    private func averageCompleteness(_ artifacts: [Artifact]) -> Double {
        guard !artifacts.isEmpty else { return 0 }
        return Double(artifacts.reduce(0) { $0 + $1.completeness.score }) / Double(artifacts.count)
    }

    private func latestUpdate(_ artifacts: [Artifact]) -> Date {
        artifacts.map { artifact in
            [artifact.capturedAt, artifact.enrichment?.generatedAt, artifact.linkMetadata?.fetchedAt]
                .compactMap { $0 }.max() ?? artifact.capturedAt
        }.max() ?? .distantPast
    }

    private var needsReviewCount: Int {
        library.artifacts.lazy.filter(\.needsPlaceReview).count
    }

    private var savedFilters: [SavedLibraryFilter] {
        SavedLibraryFilterStore.decode(savedFiltersJSON)
    }

    private var selectedSavedFilter: SavedLibraryFilter? {
        guard let id = UUID(uuidString: selectedSavedFilterRaw) else { return nil }
        return savedFilters.first { $0.id == id }
    }

    private var incompleteCount: Int { library.artifacts.lazy.filter { !$0.completeness.isComplete }.count }

    private var repeatedPlaceGroups: [RepeatedPlaceGroup] {
        Dictionary(grouping: library.artifacts.compactMap { artifact -> (SavedPlace, Artifact)? in
            artifact.place.map { ($0, artifact) }
        }, by: { $0.0.id })
        .values
        .compactMap { values in
            guard let place = values.first?.0, values.count > 1 else { return nil }
            return RepeatedPlaceGroup(
                place: place,
                artifacts: values.map(\.1).sorted { $0.capturedAt > $1.capturedAt }
            )
        }
        .sorted {
            if $0.artifacts.count != $1.artifacts.count { return $0.artifacts.count > $1.artifacts.count }
            return $0.place.name.localizedCaseInsensitiveCompare($1.place.name) == .orderedAscending
        }
    }

    @ViewBuilder
    private var savesContent: some View {
        if filteredArtifacts.isEmpty {
            if query.isEmpty {
                emptyState("No saves yet", icon: "square.stack", detail: "Save a link or note to start your library.")
            } else {
                noResultsState()
            }
        } else if isSelectingSaves {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredArtifacts) { artifact in
                        Button {
                            if selectedArtifactIDs.contains(artifact.id) {
                                selectedArtifactIDs.remove(artifact.id)
                            } else {
                                selectedArtifactIDs.insert(artifact.id)
                            }
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: selectedArtifactIDs.contains(artifact.id) ? "checkmark.circle.fill" : "circle")
                                    .font(GravitiTypography.title3)
                                    .foregroundStyle(selectedArtifactIDs.contains(artifact.id) ? GravitiColors.signalMint : .secondary)
                                ArtifactRow(artifact: artifact)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityValue(selectedArtifactIDs.contains(artifact.id) ? "Selected" : "Not selected")
                        .padding(.horizontal, 20)
                        .padding(.vertical, 6)
                        .background(selectionFrame(for: "save:\(artifact.id.uuidString)"))
                        Divider().padding(.leading, 20)
                    }
                }
            }
            .coordinateSpace(name: "librarySelectionList")
            .onPreferenceChange(LibrarySelectionFramePreferenceKey.self) { selectionRowFrames = $0 }
            .highPriorityGesture(selectionDragGesture(for: .saves))
        } else {
            List(filteredArtifacts) { artifact in
                NavigationLink {
                    SavedArtifactDetailView(artifact: artifact, library: library)
                } label: {
                    ArtifactRow(artifact: artifact)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        deleteSave(artifact.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .listRowBackground(GravitiColors.deepInk)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private func libraryLoadError(_ error: String) -> some View {
        ContentUnavailableView {
            Label("Library couldn't load", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error)
        } actions: {
            Button("Try Again") { Task { await library.load() } }
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

private struct LibraryBackupStatus: Identifiable {
    let id = UUID()
    let message: String
}

private struct LibraryActionError: Identifiable {
    let id = UUID()
    let message: String
}

private struct PendingLibraryUndo: Identifiable {
    enum Payload {
        case artifact(Artifact)
        case place([Artifact])
    }
    let id = UUID()
    let message: String
    let payload: Payload
}

private enum LibrarySelectionKind {
    case places
    case saves

    var keyPrefix: String {
        switch self {
        case .places: "place:"
        case .saves: "save:"
        }
    }
}

private struct LibrarySelectionFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private enum LibraryMode: String, CaseIterable, Identifiable {
    case destinations
    case places
    case saves
    case map
    case inbox

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .destinations: "Destinations"
        case .places: "Places"
        case .saves: "Saves"
        case .map: "Map"
        case .inbox: "Inbox"
        }
    }
}

private enum LibrarySort: String, CaseIterable, Identifiable {
    case recentlySaved, alphabetical, distance, gravity, fit, mostEvidence, leastComplete, recentlyUpdated
    var id: Self { self }
    var title: String {
        switch self {
        case .recentlySaved: String(localized: "Recently saved")
        case .alphabetical: String(localized: "Alphabetical")
        case .distance: String(localized: "Distance")
        case .gravity: String(localized: "Gravity")
        case .fit: String(localized: "Fit")
        case .mostEvidence: String(localized: "Most evidence")
        case .leastComplete: String(localized: "Least complete")
        case .recentlyUpdated: String(localized: "Recently updated")
        }
    }
    func areInIncreasingOrder(_ lhs: Artifact, _ rhs: Artifact) -> Bool {
        switch self {
        case .recentlySaved, .recentlyUpdated: return lhs.capturedAt > rhs.capturedAt
        case .alphabetical: return lhs.libraryTitle.localizedCaseInsensitiveCompare(rhs.libraryTitle) == .orderedAscending
        case .distance:
            if lhs.place == nil { return false }
            if rhs.place == nil { return true }
            return lhs.capturedAt > rhs.capturedAt
        case .mostEvidence:
            let left = lhs.effectiveInterests.count + (lhs.userNote?.trimmedNil == nil ? 0 : 2) + (lhs.effectiveSummary?.trimmedNil == nil ? 0 : 1)
            let right = rhs.effectiveInterests.count + (rhs.userNote?.trimmedNil == nil ? 0 : 2) + (rhs.effectiveSummary?.trimmedNil == nil ? 0 : 1)
            return left == right ? lhs.capturedAt > rhs.capturedAt : left > right
        case .leastComplete:
            return lhs.completeness.score == rhs.completeness.score
                ? lhs.capturedAt > rhs.capturedAt
                : lhs.completeness.score < rhs.completeness.score
        case .gravity, .fit: return lhs.capturedAt > rhs.capturedAt
        }
    }
}

private enum LibrarySmartFilter: String, CaseIterable, Identifiable {
    case all, unvisitedScenery, bostonRestaurants, nationalParks, recentlyAdded, needsDescription, instagram, withoutNotes, visitedLoved, matcha
    var id: Self { self }
    var title: String {
        switch self {
        case .all: String(localized: "All")
        case .unvisitedScenery: String(localized: "Unvisited scenery")
        case .bostonRestaurants: String(localized: "Boston restaurants")
        case .nationalParks: String(localized: "National parks")
        case .recentlyAdded: String(localized: "Recently added")
        case .needsDescription: String(localized: "Needs description")
        case .instagram: String(localized: "From Instagram")
        case .withoutNotes: String(localized: "Without notes")
        case .visitedLoved: String(localized: "Visited & loved")
        case .matcha: String(localized: "Matcha everywhere")
        }
    }
    var symbol: String {
        switch self {
        case .all: "square.grid.2x2"
        case .unvisitedScenery: "mountain.2"
        case .bostonRestaurants: "fork.knife"
        case .nationalParks: "tree.fill"
        case .recentlyAdded: "clock"
        case .needsDescription: "text.badge.xmark"
        case .instagram: "camera.fill"
        case .withoutNotes: "note.text.badge.plus"
        case .visitedLoved: "heart.fill"
        case .matcha: "cup.and.saucer.fill"
        }
    }
    func matches(_ artifact: Artifact) -> Bool {
        let text = artifact.librarySearchText
        switch self {
        case .all: return true
        case .unvisitedScenery:
            return artifact.effectiveCategory == .sceneryAndNature &&
                ![.visited, .loved, .didNotFit].contains(artifact.userDetails?.placeStatus ?? .saved)
        case .bostonRestaurants:
            let location = [artifact.place?.locality, artifact.place?.region].compactMap { $0 }.joined(separator: " ")
            return artifact.effectiveCategory == .foodAndDrink && location.localizedCaseInsensitiveContains("Boston")
        case .nationalParks: return text.localizedCaseInsensitiveContains("national park")
        case .recentlyAdded: return artifact.capturedAt >= (Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .distantPast)
        case .needsDescription: return artifact.effectiveSummary?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false
        case .instagram:
            guard let host = artifact.sourceURL.flatMap({ URLComponents(string: $0)?.host?.lowercased() }) else { return false }
            return host == "instagram.com" || host.hasSuffix(".instagram.com")
        case .withoutNotes: return artifact.userNote?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false
        case .visitedLoved: return artifact.userDetails?.placeStatus == .loved
        case .matcha: return text.localizedCaseInsensitiveContains("matcha")
        }
    }
}

private struct ArtifactRow: View {
    let artifact: Artifact

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ArtifactThumbnailView(artifact: artifact)

            VStack(alignment: .leading, spacing: 4) {
                Text(artifact.libraryTitle)
                    .font(GravitiTypography.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)

                if let supportingText {
                    Text(supportingText)
                        .font(GravitiTypography.subheadline)
                        .foregroundStyle(.white.opacity(0.68))
                        .lineLimit(2)
                }

                HStack(spacing: 5) {
                    if let category = artifact.effectiveCategory {
                        Text(category.displayName)
                            .foregroundStyle(GravitiColors.signalMint)
                    } else if let siteName = artifact.linkMetadata?.siteName {
                        Text(siteName)
                            .foregroundStyle(GravitiColors.signalMint)
                    }
                    if artifact.effectiveCategory != nil || artifact.linkMetadata?.siteName != nil {
                        Text("·")
                    }
                    Text(artifact.place?.name ?? artifact.capturedAt.formatted(.dateTime.month().day().year()))
                        .lineLimit(1)
                }
                .font(GravitiTypography.caption)
                .foregroundStyle(.white.opacity(0.58))

                if artifact.processingState == .needsReview || artifact.processingState == .failed {
                    Text(artifact.processingState == .needsReview ? "Needs place review" : "Place lookup failed")
                        .font(GravitiTypography.captionSemibold)
                        .foregroundStyle(GravitiColors.opportunityCoral)
                }

            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 7)
        .accessibilityElement(children: .combine)
    }

    private var supportingText: String? {
        let candidates: [String?] = [
            artifact.effectiveSummary,
            artifact.linkMetadata?.summary,
            artifact.userNote,
            artifact.kind == .manual ? artifact.originalText : nil,
            artifact.kind == .url ? URL(string: artifact.sourceURL ?? "")?.host(percentEncoded: false) : nil
        ]
        for candidate in candidates {
            guard let value = candidate?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty,
                  value.localizedCaseInsensitiveCompare(artifact.libraryTitle) != .orderedSame else { continue }
            return value
        }
        return nil
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
            if let title = linkMetadata?.title, !title.isEmpty { return title }
            guard let source = sourceURL else { return String(localized: "Saved link") }
            if MapLinkMetadata.isCollectionLink(source),
               let provider = MapLinkMetadata.provider(for: source) {
                return provider == .apple
                    ? String(localized: "Apple Maps guide")
                    : String(localized: "Google Maps list")
            }
            return URLComponents(string: source)?.host ?? source
        case .manual:
            return originalText?.split(whereSeparator: \.isNewline).first.map(String.init) ?? String(localized: "Saved note")
        case .photo:
            return userNote?.split(whereSeparator: \.isNewline).first.map(String.init) ?? String(localized: "Saved photo")
        }
    }

    var librarySearchText: String {
        [
            libraryTitle,
            sourceURL,
            originalText,
            linkMetadata?.title,
            linkMetadata?.summary,
            linkMetadata?.siteName,
            userNote,
            effectiveSummary,
            effectiveCategory?.displayName,
            effectiveInterests.joined(separator: " "),
            InterestDisplayName.joined(effectiveInterests, separator: " "),
            place?.name,
            place?.locality,
            place?.region,
            place?.country
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }
}
