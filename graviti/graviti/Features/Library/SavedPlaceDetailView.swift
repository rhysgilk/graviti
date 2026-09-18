import SwiftUI
import MapKit

struct SavedPlaceDetailView: View {
    let place: SavedPlace
    let artifacts: [Artifact]
    @ObservedObject var library: ArtifactLibrary

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

                Text("Saved items")
                    .font(.headline)
                ForEach(artifacts) { artifact in
                    NavigationLink {
                        SavedArtifactDetailView(artifact: artifact, library: library)
                    } label: {
                        HStack {
                            Text(artifact.originalText ?? "Saved link")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding(16)
                        .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .background(GravitiColors.appBackground)
        .navigationTitle(place.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
