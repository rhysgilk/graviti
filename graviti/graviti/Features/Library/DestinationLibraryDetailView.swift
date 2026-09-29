import SwiftUI
import MapKit
import UIKit

struct DestinationLibraryDetailView: View {
    let node: OrbitNode
    @ObservedObject var library: ArtifactLibrary
    @State private var selectedCategory: ExperienceCategory?
    @State private var displayMode: DestinationSaveDisplayMode = .cards
    @State private var selectedCardID: UUID?
    @State private var detailArtifactID: UUID?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                destinationHeader
                if !matchingArtifacts.isEmpty {
                    destinationMap
                    categoryPicker
                    displayModePicker
                    if filteredArtifacts.isEmpty {
                        emptyCategory
                    } else if displayMode == .cards {
                        cardDeck
                    } else {
                        saveList
                    }
                }
                if !children.isEmpty { areasSection }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(GravitiColors.appBackground)
        .navigationTitle(node.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $detailArtifactID) { artifactID in
            destinationDetail(for: artifactID)
        }
        .onChange(of: selectedCategory) { _, _ in
            alignFirstCardAfterLayout()
        }
        .onChange(of: filteredArtifacts.map(\.id)) { _, ids in
            if selectedCardID.map(ids.contains) != true { alignFirstCardAfterLayout() }
        }
    }

    private var destinationHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(node.name)
                .font(.custom("Sora-SemiBold", size: 30, relativeTo: .largeTitle))
            HStack(spacing: 8) {
                Label(GravitiCopy.savedItems(matchingArtifacts.count), systemImage: "square.stack.fill")
                Text("·")
                Text("\(Int(node.gravity)) Gravity")
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            if !profile.interests.isEmpty {
                Text(InterestDisplayName.joined(profile.interests.prefix(5).map(\.name)))
                    .font(.subheadline)
                    .foregroundStyle(GravitiColors.signalMint)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
    }

    private var destinationMap: some View {
        Map(initialPosition: .automatic) {
            ForEach(filteredPlaces) { place in
                let category = PlaceMapCategoryStyle.category(for: place.id, in: filteredArtifacts)
                Marker(
                    place.name,
                    systemImage: category.mapSymbolName,
                    coordinate: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
                )
                .tint(category.mapTint)
            }
        }
        .id(mapIdentity)
        .frame(height: 245)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(alignment: .bottomLeading) {
            Label(mappedPlacesLabel, systemImage: "mappin.and.ellipse")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(minHeight: 34)
                .background(.black.opacity(0.7), in: Capsule())
                .padding(12)
        }
        .accessibilityLabel("Map of saved places in \(node.name)")
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                categoryButton(nil, title: String(localized: "All saved"), count: matchingArtifacts.count)
                ForEach(availableCategories, id: \.self) { category in
                    categoryButton(category, title: category.displayName, count: matchingArtifacts.filter {
                        ($0.effectiveCategory ?? .other) == category
                    }.count)
                }
            }
            .padding(.vertical, 2)
        }
        .contentMargins(.horizontal, 0, for: .scrollContent)
        .accessibilityLabel("Filter saves by category")
    }

    private func categoryButton(_ category: ExperienceCategory?, title: String, count: Int) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.24)) { selectedCategory = category }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: categoryIcon(category))
                Text(title)
                Text("\(count)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(isSelected(category) ? GravitiColors.deepInk : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(isSelected(category) ? Color.white.opacity(0.78) : Color.white.opacity(0.08), in: Capsule())
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isSelected(category) ? GravitiColors.deepInk : .white.opacity(0.78))
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(isSelected(category) ? GravitiColors.signalMint : GravitiColors.deepInk, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected(category) ? .isSelected : [])
    }

    private var displayModePicker: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedCategory?.displayName ?? String(localized: "All saved places"))
                    .font(.headline)
                Text(GravitiCopy.savedItems(filteredArtifacts.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("Display", selection: $displayMode) {
                ForEach(DestinationSaveDisplayMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.icon).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 128)
        }
    }

    private var cardDeck: some View {
        VStack(spacing: 14) {
            GeometryReader { proxy in
                let cardWidth = max(250, proxy.size.width - 96)
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 14) {
                        ForEach(filteredArtifacts) { artifact in
                            DestinationSaveCard(artifact: artifact)
                                .frame(width: cardWidth)
                                .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                                .onTapGesture { detailArtifactID = artifact.id }
                                .accessibilityAddTraits(.isButton)
                                .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                    content
                                        .scaleEffect(phase.isIdentity ? 1 : 0.92)
                                        .opacity(phase.isIdentity ? 1 : 0.7)
                                        .rotation3DEffect(
                                            .degrees(Double(phase.value) * 5),
                                            axis: (x: 0, y: 1, z: 0)
                                        )
                                }
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, 48, for: .scrollContent)
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                .scrollPosition(id: $selectedCardID, anchor: .center)
                .onAppear { alignFirstCardAfterLayout() }
            }
            .frame(height: 405)

            HStack(spacing: 16) {
                deckButton(icon: "chevron.left", disabled: selectedCardIndex == 0) { moveCard(by: -1) }
                Text("\(selectedCardIndex + 1) of \(filteredArtifacts.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 72)
                deckButton(icon: "chevron.right", disabled: selectedCardIndex >= filteredArtifacts.count - 1) { moveCard(by: 1) }
            }
        }
        .padding(.bottom, 10)
    }

    private func deckButton(icon: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .frame(width: 40, height: 40)
                .background(GravitiColors.deepInk, in: Circle())
        }
        .disabled(disabled)
        .foregroundStyle(.white)
    }

    private var saveList: some View {
        LazyVStack(spacing: 10) {
            ForEach(filteredArtifacts) { artifact in
                NavigationLink {
                    SavedArtifactDetailView(artifact: artifact, library: library)
                } label: {
                    DestinationArtifactRow(artifact: artifact)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyCategory: some View {
        ContentUnavailableView("Nothing saved here yet", systemImage: categoryIcon(selectedCategory), description: Text("Choose another category to keep exploring \(node.name)."))
            .frame(maxWidth: .infinity, minHeight: 260)
    }

    private var areasSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Explore areas").font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(children) { child in
                        NavigationLink {
                            DestinationLibraryDetailView(node: child, library: library)
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(child.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                                Text(GravitiCopy.savedItems(child.saveCount)).font(.caption).foregroundStyle(.secondary)
                            }
                            .frame(width: 150, alignment: .leading)
                            .padding(14)
                            .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var children: [OrbitNode] { DestinationOrbitBuilder.children(of: node, from: library.artifacts, limit: nil) }
    private var matchingArtifacts: [Artifact] { DestinationOrbitBuilder.artifacts(for: node, from: library.artifacts) }
    private var filteredArtifacts: [Artifact] {
        guard let selectedCategory else { return matchingArtifacts }
        return matchingArtifacts.filter { ($0.effectiveCategory ?? .other) == selectedCategory }
    }
    private var availableCategories: [ExperienceCategory] {
        let present = Set(matchingArtifacts.map { $0.effectiveCategory ?? .other })
        return ExperienceCategory.allCases.filter(present.contains)
    }
    private var filteredPlaces: [SavedPlace] {
        var seen = Set<String>()
        return filteredArtifacts.compactMap(\.place).filter { seen.insert($0.id).inserted }
    }
    private var profile: InterestProfile { InterestProfileBuilder.build(from: matchingArtifacts) }
    private var mapIdentity: String { "\(node.id)-\(selectedCategory?.rawValue ?? "all")-\(filteredPlaces.map(\.id).joined(separator: "|"))" }
    private var mappedPlacesLabel: String { filteredPlaces.count == 1 ? String(localized: "1 place on map") : String(localized: "\(filteredPlaces.count) places on map") }

    private func isSelected(_ category: ExperienceCategory?) -> Bool { selectedCategory == category }
    private var selectedCardIndex: Int {
        guard let selectedCardID,
              let index = filteredArtifacts.firstIndex(where: { $0.id == selectedCardID }) else { return 0 }
        return index
    }
    private func alignFirstCardAfterLayout() {
        guard let firstID = filteredArtifacts.first?.id else {
            selectedCardID = nil
            return
        }
        selectedCardID = nil
        DispatchQueue.main.async {
            selectedCardID = firstID
        }
    }
    private func moveCard(by amount: Int) {
        guard !filteredArtifacts.isEmpty else { return }
        let target = min(max(0, selectedCardIndex + amount), filteredArtifacts.count - 1)
        withAnimation(.snappy(duration: 0.32)) { selectedCardID = filteredArtifacts[target].id }
    }
    private func categoryIcon(_ category: ExperienceCategory?) -> String {
        switch category {
        case nil: "square.stack.fill"
        case .foodAndDrink: "fork.knife"
        case .sceneryAndNature: "mountain.2.fill"
        case .artsAndCulture: "theatermasks.fill"
        case .activities: "figure.hiking"
        case .shopping: "bag.fill"
        case .landmarks: "building.columns.fill"
        case .stay: "bed.double.fill"
        case .other: "mappin"
        }
    }

    @ViewBuilder
    private func destinationDetail(for artifactID: UUID) -> some View {
        if let artifact = library.artifacts.first(where: { $0.id == artifactID }) {
            SavedArtifactDetailView(artifact: artifact, library: library)
        } else {
            ContentUnavailableView("Save no longer available", systemImage: "trash")
        }
    }
}

private enum DestinationSaveDisplayMode: String, CaseIterable, Identifiable {
    case cards, list
    var id: String { rawValue }
    var title: String { self == .cards ? String(localized: "Cards") : String(localized: "List") }
    var icon: String { self == .cards ? "rectangle.stack.fill" : "list.bullet" }
}

private struct DestinationSaveCard: View {
    let artifact: Artifact

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardVisual.frame(height: 245).clipped()
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).font(.custom("Sora-SemiBold", size: 21, relativeTo: .title3)).lineLimit(2)
                    Spacer(minLength: 10)
                    Image(systemName: "arrow.up.right").font(.caption.weight(.bold)).foregroundStyle(GravitiColors.signalMint)
                }
                if let summary = artifact.effectiveSummary, summary != title {
                    Text(summary).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
                } else if artifact.enrichmentState == .pending || artifact.enrichmentState == .processing {
                    Label("Learning about this save…", systemImage: "sparkles").font(.subheadline).foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    if let category = artifact.effectiveCategory {
                        Label(category.displayName, systemImage: "circle.fill").foregroundStyle(GravitiColors.signalMint)
                    }
                    if let place = artifact.place {
                        Text(place.subtitle).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                .font(.caption.weight(.medium))
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Color.white.opacity(0.08)))
        .shadow(color: .black.opacity(0.34), radius: 18, y: 12)
    }

    @ViewBuilder private var cardVisual: some View {
        if let mediaKey = artifact.mediaKey {
            MediaPreviewView(mediaKey: mediaKey, maximumPixelSize: 1_200, minimumHeight: 245, contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let data = artifact.linkMetadata?.imageData, let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFill()
        } else if let place = artifact.place {
            Map(initialPosition: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.018, longitudeDelta: 0.018)
            ))) {
                let category = artifact.effectiveCategory ?? .other
                Marker(
                    place.name,
                    systemImage: category.mapSymbolName,
                    coordinate: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
                )
                .tint(category.mapTint)
            }
            .allowsHitTesting(false)
        } else {
            LinearGradient(colors: [GravitiColors.iris.opacity(0.55), GravitiColors.deepInk], startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay { Image(systemName: "sparkles").font(.system(size: 42, weight: .medium)).foregroundStyle(GravitiColors.signalMint) }
        }
    }

    private var title: String { artifact.place?.name ?? artifact.originalText ?? artifact.userNote ?? artifact.sourceURL ?? String(localized: "Saved item") }
}

private struct DestinationArtifactRow: View {
    let artifact: Artifact
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ArtifactThumbnailView(artifact: artifact, size: 64)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline).lineLimit(2)
                if let summary = artifact.effectiveSummary, summary != title {
                    Text(summary).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                }
                if let category = artifact.effectiveCategory {
                    Text(category.displayName).font(.caption.weight(.medium)).foregroundStyle(GravitiColors.signalMint)
                }
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary).padding(.top, 4)
        }
        .accessibilityElement(children: .combine)
    }
    private var title: String { artifact.place?.name ?? artifact.originalText ?? artifact.userNote ?? artifact.sourceURL ?? String(localized: "Saved item") }
}
