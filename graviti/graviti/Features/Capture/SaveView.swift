import SwiftUI
import UniformTypeIdentifiers
import PhotosUI
import UIKit

struct SaveView: View {
    @ObservedObject var library: ArtifactLibrary
    let onViewLibrary: () -> Void
    let onFindPlace: () -> Void

    @State private var kind: ArtifactKind = .url
    @State private var urlText = ""
    @State private var noteText = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var optionalNote = ""
    @State private var isSaving = false
    @State private var didSave = false
    @State private var saveError: String?
    @State private var showingCSVImporter = false
    @State private var showingMapsLinkImporter = false
    @State private var importMessage: String?
    @State private var importSummary: SaveImportSummary?
    @FocusState private var focusedField: SaveField?
#if DEBUG
    @AppStorage("debug.dogfoodArtifactIDs") private var dogfoodArtifactIDs = ""
    @State private var isChangingDogfood = false
#endif

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Save what pulls you.")
                        .font(.custom("Sora-SemiBold", size: 26, relativeTo: .title))
                        .foregroundStyle(.white)

                    Picker("Save type", selection: $kind) {
                        Text("Link").tag(ArtifactKind.url)
                        Text("Note").tag(ArtifactKind.manual)
                        Text("Photo").tag(ArtifactKind.photo)
                    }
                    .pickerStyle(.segmented)

                    if kind == .url {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Link")
                                .font(.headline)
                            TextField("Paste a link", text: $urlText)
                                .focused($focusedField, equals: .url)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.URL)
                                .textContentType(.URL)
                                .submitLabel(.done)
                                .onSubmit { focusedField = nil }
                                .padding(14)
                                .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 12))
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("A note, if you like")
                                .font(.headline)
                            TextField("What caught your eye?", text: $optionalNote, axis: .vertical)
                                .focused($focusedField, equals: .optionalNote)
                                .lineLimit(2...4)
                                .padding(14)
                                .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 12))
                        }
                    } else if kind == .manual {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Your note")
                                .font(.headline)
                            TextEditor(text: $noteText)
                                .focused($focusedField, equals: .note)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 140)
                                .padding(10)
                                .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 12))
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Photo or screenshot")
                                .font(.headline)
                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                Label(selectedPhoto == nil ? "Choose from Photos" : "Change photo", systemImage: "photo.on.rectangle")
                                    .frame(maxWidth: .infinity, minHeight: 48)
                                    .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)

                            if selectedPhoto != nil {
                                Label("Photo selected", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(GravitiColors.signalMint)
                                    .font(.subheadline)
                            }

                            TextField("What caught your eye? (optional)", text: $optionalNote, axis: .vertical)
                                .focused($focusedField, equals: .optionalNote)
                                .lineLimit(2...4)
                                .padding(14)
                                .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    Button {
                        focusedField = nil
                        Task { await save() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Text("Save to Graviti")
                                    .font(.headline)
                            }
                            Spacer()
                        }
                        .frame(minHeight: 50)
                        .background(GravitiColors.iris, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSave || isSaving)
                    .opacity(canSave ? 1 : 0.5)

                    if didSave {
                        HStack {
                            Label("Saved to Graviti", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(GravitiColors.signalMint)
                            Spacer()
                            Button("View in Library", action: onViewLibrary)
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                        .accessibilityElement(children: .contain)
                    }

                    if let saveError {
                        Text(saveError)
                            .font(.subheadline)
                            .foregroundStyle(GravitiColors.opportunityCoral)
                    }

                    if let importSummary {
                        ImportSummaryCard(summary: importSummary)
                    }

                    if let importMessage {
                        Text(importMessage)
                            .font(.subheadline)
                            .foregroundStyle(GravitiColors.signalMint)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Bring in saved places")
                            .font(.headline)

                        Button(action: onFindPlace) {
                            Label("Find a place", systemImage: "magnifyingglass")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)

                        Text("Paste an Apple Maps or Google Maps link to save a place or import a shared guide or list. You can also import Google Takeout CSVs and .webloc files.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))

                        HStack(spacing: 12) {
                            Label("Paste Maps link", systemImage: "doc.on.clipboard")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            PasteButton(payloadType: URL.self) { urls in
                                guard let url = urls.first else { return }
                                focusedField = nil
                                kind = .url
                                urlText = url.absoluteString
                                Task { await save() }
                            }
                            .tint(GravitiColors.iris)
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 52)
                        .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 14))

                        if let googleTakeoutURL = URL(string: "https://takeout.google.com") {
                            Link("Open Google Takeout", destination: googleTakeoutURL)
                                .font(.subheadline.weight(.semibold))
                        }

                        Button {
                            showingCSVImporter = true
                        } label: {
                            Label("Import Google Saved CSV", systemImage: "square.and.arrow.down")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)

                        Button {
                            showingMapsLinkImporter = true
                        } label: {
                            Label("Import .webloc file", systemImage: "link.badge.plus")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)

#if DEBUG
                        dogfoodControls
#endif
                    }
                    .padding(.top, 8)
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(GravitiColors.appBackground)
            .foregroundStyle(.white)
            .navigationTitle("Save")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: kind) { _, _ in didSave = false }
        .onChange(of: urlText) { _, newValue in
            if !newValue.isEmpty { didSave = false }
        }
        .onChange(of: noteText) { _, newValue in
            if !newValue.isEmpty { didSave = false }
        }
        .fileImporter(
            isPresented: $showingCSVImporter,
            allowedContentTypes: [.commaSeparatedText]
        ) { result in
            switch result {
            case .success(let fileURL):
                Task {
                    do {
                        let summary = try await library.importGoogleSavedCSV(from: fileURL)
                        importMessage = nil
                        importSummary = SaveImportSummary(
                            title: String(localized: "Google Maps import complete"),
                            imported: summary.imported,
                            duplicates: summary.duplicates,
                            skipped: summary.skipped,
                            processingContinues: summary.imported > 0
                        )
                    } catch {
                        importSummary = nil
                        importMessage = error.localizedDescription
                    }
                }
            case .failure(let error):
                importSummary = nil
                importMessage = error.localizedDescription
            }
        }
        .fileImporter(
            isPresented: $showingMapsLinkImporter,
            allowedContentTypes: [UTType(filenameExtension: "webloc") ?? .data]
        ) { result in
            switch result {
            case .success(let fileURL):
                Task {
                    do {
                        let url = try await library.importMapsLinkFile(from: fileURL)
                        importSummary = nil
                        importMessage = String(localized: "Maps link saved to Library.")
                        await importMapCollectionIfNeeded(url)
                    } catch {
                        importSummary = nil
                        importMessage = error.localizedDescription
                    }
                }
            case .failure(let error):
                importSummary = nil
                importMessage = error.localizedDescription
            }
        }
    }

    private var canSave: Bool {
        switch kind {
        case .url:
            guard let components = URLComponents(string: urlText.trimmingCharacters(in: .whitespacesAndNewlines)),
                  let scheme = components.scheme?.lowercased(),
                  ["http", "https"].contains(scheme),
                  let host = components.host, !host.isEmpty else {
                return false
            }
            return true
        case .manual:
            return !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .photo:
            return selectedPhoto != nil
        }
    }

    private func save() async {
        guard canSave, !isSaving else { return }
        focusedField = nil
        isSaving = true
        didSave = false
        saveError = nil

        var savedURL: String?
        do {
            switch kind {
            case .url:
                let url = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
                savedURL = url
                let note = optionalNote.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                let collectionAlreadySaved = note == nil && library.artifacts.contains {
                    $0.sourceURL == url && ArtifactProcessingCoordinator.isResolvedMapCollection($0)
                }
                if !collectionAlreadySaved {
                    try await library.save(Artifact(
                        kind: .url,
                        sourceURL: url,
                        originalText: MapLinkMetadata.placeName(from: url),
                        userNote: note
                    ))
                }
            case .manual:
                try await library.save(Artifact(
                    kind: .manual,
                    originalText: noteText.trimmingCharacters(in: .whitespacesAndNewlines)
                ))
            case .photo:
                guard let selectedPhoto,
                      let data = try await selectedPhoto.loadTransferable(type: Data.self),
                      UIImage(data: data) != nil else { throw PhotoCaptureError.unsupported }
                let fileExtension = selectedPhoto.supportedContentTypes
                    .first(where: { $0.conforms(to: .image) })?
                    .preferredFilenameExtension ?? "jpg"
                try await library.savePhoto(
                    data,
                    fileExtension: fileExtension,
                    note: optionalNote.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                )
            }
            urlText = ""
            noteText = ""
            optionalNote = ""
            selectedPhoto = nil
            didSave = true
            if let savedURL {
                Task { await importMapCollectionIfNeeded(savedURL) }
            }
        } catch {
            saveError = error.localizedDescription
        }
        isSaving = false
    }

    private func importMapCollectionIfNeeded(_ url: String) async {
        guard let provider = MapLinkMetadata.provider(for: url) else { return }
        importSummary = nil

        switch provider {
        case .apple:
            guard MapLinkMetadata.isCollectionLink(url) else { return }
            importMessage = String(localized: "Importing places from Apple Maps guide…")
            do {
                let summary = try await library.importAppleGuidePlaces(from: url)
                importMessage = nil
                importSummary = SaveImportSummary(
                    title: summary.title,
                    imported: summary.imported,
                    refreshed: summary.refreshed,
                    duplicates: summary.duplicates,
                    skipped: summary.skipped,
                    countries: summary.countries,
                    cities: summary.cities
                )
            } catch {
                importMessage = error.localizedDescription
            }
        case .google:
            importMessage = String(localized: "Checking for places in this Google Maps list…")
            do {
                let summary = try await library.importGoogleMapsListPlaces(from: url)
                importMessage = nil
                importSummary = SaveImportSummary(
                    title: summary.title,
                    imported: summary.imported,
                    refreshed: summary.refreshed,
                    duplicates: summary.duplicates,
                    skipped: summary.skipped,
                    processingContinues: summary.imported + summary.refreshed > 0
                )
            } catch GoogleMapsListError.notAList {
                importMessage = nil
            } catch {
                importMessage = error.localizedDescription
            }
        }
    }

#if DEBUG
    private var dogfoodControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider().overlay(.white.opacity(0.15))

            Text("Development test data")
                .font(.headline)

            Text("Switch between focused libraries to test how Graviti combines different interests into destination suggestions.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.65))

            Menu {
                ForEach(DogfoodDataset.allCases) { dataset in
                    Button(dataset.displayName) {
                        Task { await loadDogfood(dataset) }
                    }
                }
            } label: {
                Label(isChangingDogfood ? "Changing test data…" : "Load test dataset", systemImage: "shippingbox.and.arrow.backward")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isChangingDogfood)

            if !dogfoodArtifactIDs.isEmpty {
                Button(role: .destructive) {
                    Task { await clearDogfood() }
                } label: {
                    Label("Remove test dataset", systemImage: "trash")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .disabled(isChangingDogfood)
            }
        }
        .padding(.top, 8)
    }

    private func loadDogfood(_ dataset: DogfoodDataset) async {
        isChangingDogfood = true
        defer { isChangingDogfood = false }
        do {
            try await removeTrackedDogfood()
            let text = try dataset.csvText()
            let summary = try await library.importGoogleSavedCSV(text)
            dogfoodArtifactIDs = summary.importedIDs.map(\.uuidString).joined(separator: ",")
            importMessage = nil
            importSummary = SaveImportSummary(
                title: dataset.displayName,
                imported: summary.imported,
                duplicates: summary.duplicates,
                skipped: summary.skipped,
                processingContinues: summary.imported > 0
            )
        } catch {
            importSummary = nil
            importMessage = error.localizedDescription
        }
    }

    private func clearDogfood() async {
        isChangingDogfood = true
        defer { isChangingDogfood = false }
        do {
            try await removeTrackedDogfood()
            importSummary = nil
            importMessage = String(localized: "Test data removed.")
        } catch {
            importSummary = nil
            importMessage = error.localizedDescription
        }
    }

    private func removeTrackedDogfood() async throws {
        let ids = Set(dogfoodArtifactIDs
            .split(separator: ",")
            .compactMap { UUID(uuidString: String($0)) })
        try await library.deleteArtifacts(ids)
        dogfoodArtifactIDs = ""
    }
#endif
}

private enum SaveField: Hashable {
    case url
    case note
    case optionalNote
}

#if DEBUG
private enum DogfoodDataset: String, CaseIterable, Identifiable {
    case nationalParksAndScenery = "national-parks-and-scenery"
    case cultureAndHistory = "culture-and-history"
    case foodAndWater = "food-and-water"
    case diverseLibrary = "diverse-library"
    case crowdedLibrary = "crowded-library"

    var id: Self { self }

    var displayName: String {
        switch self {
        case .nationalParksAndScenery: "National parks & scenery"
        case .cultureAndHistory: "Culture, architecture & history"
        case .foodAndWater: "Seafood, markets & water"
        case .diverseLibrary: "Diverse mixed library"
        case .crowdedLibrary: "Crowded library stress test"
        }
    }

    func csvText() throws -> String {
        let url = Bundle.main.url(forResource: rawValue, withExtension: "csv", subdirectory: "Dogfood")
            ?? Bundle.main.url(forResource: rawValue, withExtension: "csv")
        guard let url else { throw DogfoodDatasetError.missingFile(displayName) }
        return try String(contentsOf: url, encoding: .utf8)
    }
}

private enum DogfoodDatasetError: LocalizedError {
    case missingFile(String)

    var errorDescription: String? {
        switch self {
        case .missingFile(let name): "The \(name) test dataset isn't bundled in this build."
        }
    }
}
#endif

private enum PhotoCaptureError: LocalizedError {
    case unsupported

    var errorDescription: String? { String(localized: "This photo couldn't be read. Try another image.") }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
