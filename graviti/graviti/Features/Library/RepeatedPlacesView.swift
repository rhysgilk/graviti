import SwiftUI

struct RepeatedPlaceGroup: Identifiable {
    let place: SavedPlace
    let artifacts: [Artifact]

    var id: String { place.id }
}

struct RepeatedPlacesView: View {
    let groups: [RepeatedPlaceGroup]
    @ObservedObject var library: ArtifactLibrary

    var body: some View {
        List(groups) { group in
            NavigationLink {
                SavedPlaceDetailView(place: group.place, library: library)
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(group.place.name)
                            .font(.headline)
                        Spacer()
                        Text("\(group.artifacts.count) saves")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(GravitiColors.signalMint)
                    }

                    if !group.place.subtitle.isEmpty {
                        Text(group.place.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text(group.artifacts.prefix(3).map(artifactTitle).joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(2)
                }
                .padding(.vertical, 7)
                .accessibilityElement(children: .combine)
                .accessibilityHint("Shows every save connected to this place")
            }
            .listRowBackground(GravitiColors.deepInk)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(GravitiColors.appBackground)
        .navigationTitle("Repeated places")
        .safeAreaInset(edge: .top) {
            Text("Each original save stays in your Library. Graviti connects them to one place so repeated interest strengthens its signal without creating duplicate places.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(GravitiColors.appBackground)
        }
    }

    private func artifactTitle(_ artifact: Artifact) -> String {
        artifact.originalText
            ?? artifact.userNote
            ?? artifact.sourceURL.flatMap { URLComponents(string: $0)?.host }
            ?? "Saved item"
    }
}
