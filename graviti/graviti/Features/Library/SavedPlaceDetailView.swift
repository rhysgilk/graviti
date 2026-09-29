import SwiftUI
import MapKit

struct SavedPlaceDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let place: SavedPlace
    @ObservedObject var library: ArtifactLibrary
    @State private var showingRemoveConfirmation = false
    @State private var actionError: String?
    @State private var isRemoving = false
    @State private var isUpdatingStatus = false

    private var artifacts: [Artifact] {
        library.artifacts.filter { $0.place?.id == place.id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude),
                    span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
                ))) {
                    let category = PlaceMapCategoryStyle.category(for: place.id, in: artifacts)
                    Marker(
                        place.name,
                        systemImage: category.mapSymbolName,
                        coordinate: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
                    )
                    .tint(category.mapTint)
                }
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .accessibilityLabel("Map showing \(place.name)")

                VStack(alignment: .leading, spacing: 6) {
                    Text(place.name)
                        .font(.custom("Sora-SemiBold", size: 26, relativeTo: .title))
                    Text(place.subtitle)
                        .foregroundStyle(.secondary)
                }

                PlaceStatusRail(
                    selection: library.placeStatus(for: place.id),
                    isUpdating: isUpdatingStatus
                ) { status in
                    isUpdatingStatus = true
                    Task {
                        do {
                            try await library.setPlaceStatus(status, for: place.id)
                        } catch {
                            actionError = error.localizedDescription
                        }
                        isUpdatingStatus = false
                    }
                }

                if artifacts.count > 1 {
                    Label {
                        Text("\(artifacts.count) separate saves connect to this one place. Each original remains available and contributes to its Gravity and interest signals.")
                    } icon: {
                        Image(systemName: "square.on.square")
                            .foregroundStyle(GravitiColors.signalMint)
                    }
                    .font(.subheadline)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 14))
                }

                Text("Your saves")
                    .font(.headline)
                ForEach(artifacts) { artifact in
                    NavigationLink {
                        SavedArtifactDetailView(artifact: artifact, library: library)
                    } label: {
                        HStack {
                            Text(artifact.originalText ?? String(localized: "Saved link"))
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding(16)
                        .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }

                if let actionError {
                    Text(actionError)
                        .font(.subheadline)
                        .foregroundStyle(GravitiColors.opportunityCoral)
                }

                Button(role: .destructive) { showingRemoveConfirmation = true } label: {
                    Label("Remove place from Library", systemImage: "mappin.slash")
                        .font(.subheadline.weight(.semibold))
                }
                .disabled(isRemoving)
                .padding(.top, 8)
            }
            .padding(20)
        }
        .background(GravitiColors.appBackground)
        .navigationTitle(place.name)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Remove \(place.name) from your places?",
            isPresented: $showingRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove place", role: .destructive) {
                isRemoving = true
                Task {
                    do {
                        try await library.removePlaceFromLibrary(place.id)
                        dismiss()
                    } catch {
                        actionError = error.localizedDescription
                        isRemoving = false
                    }
                }
            }
        } message: {
            Text("The \(artifacts.count) associated saves stay in your Library without a place. You can match them again later.")
        }
    }
}

private struct PlaceStatusRail: View {
    let selection: PlaceLifecycleStatus
    let isUpdating: Bool
    let onSelect: (PlaceLifecycleStatus) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Your journey")
                    .font(GravitiTypography.headline)
                Spacer()
                Text(selection.title)
                    .font(GravitiTypography.captionSemibold)
                    .foregroundStyle(GravitiColors.signalMint)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    ForEach(PlaceLifecycleStatus.allCases) { status in
                        Button { onSelect(status) } label: {
                            VStack(spacing: 6) {
                                Image(systemName: status.symbol)
                                    .font(.system(size: 17, weight: .semibold))
                                    .frame(width: 38, height: 38)
                                    .background(selection == status ? GravitiColors.iris : .white.opacity(0.07), in: Circle())
                                    .overlay(Circle().strokeBorder(selection == status ? GravitiColors.signalMint.opacity(0.8) : .white.opacity(0.08)))
                                Text(status.title)
                                    .font(GravitiTypography.caption)
                                    .lineLimit(1)
                            }
                            .foregroundStyle(selection == status ? .white : .white.opacity(0.62))
                        }
                        .buttonStyle(.plain)
                        .disabled(isUpdating)
                        .accessibilityAddTraits(selection == status ? .isSelected : [])
                    }
                }
            }
            Text("Status applies to this place across all of its saves and can help future recommendations learn from what happened.")
                .font(GravitiTypography.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 18))
    }
}
