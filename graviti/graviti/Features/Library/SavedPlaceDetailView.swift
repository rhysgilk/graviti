import SwiftUI
import MapKit

struct SavedPlaceDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let place: SavedPlace
    @ObservedObject var library: ArtifactLibrary
    @State private var showingRemoveConfirmation = false
    @State private var actionError: String?
    @State private var isRemoving = false

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
                    Marker(place.name, coordinate: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude))
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
