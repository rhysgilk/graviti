import SwiftUI

struct SavedArtifactDetailView: View {
    let artifact: Artifact

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Label(sourceLabel, systemImage: artifact.kind == .url ? "link" : "note.text")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GravitiColors.signalMint)

                if let sourceURL = artifact.sourceURL {
                    Text(sourceURL)
                        .font(.body)
                        .textSelection(.enabled)
                        .foregroundStyle(.white)

                    if MapLinkMetadata.isCollectionLink(sourceURL) {
                        Text(MapLinkMetadata.provider(for: sourceURL) == .google
                             ? "This saves the list link. To add each place, import its Google Saved CSV from the Save tab."
                             : "This saves the guide link. Its places aren't imported individually yet.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.68))
                    }

                    if let url = openableURL(sourceURL) {
                        Link(destination: url) {
                            Label("Open original", systemImage: "arrow.up.right")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(GravitiColors.iris, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .foregroundStyle(.white)
                    }
                }

                if let originalText = artifact.originalText {
                    if artifact.kind == .url {
                        Text(MapLinkMetadata.provider(for: artifact.sourceURL ?? "") == nil
                             ? "Source title" : "Saved place")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    Text(originalText)
                        .font(.body)
                        .textSelection(.enabled)
                        .foregroundStyle(.white)
                }

                if let userNote = artifact.userNote {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your note")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.65))
                        Text(userNote)
                            .textSelection(.enabled)
                            .foregroundStyle(.white)
                    }
                }

                Text("Saved \(artifact.capturedAt, format: .dateTime.month().day().year())")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background(GravitiColors.appBackground)
        .navigationTitle("Saved item")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func openableURL(_ raw: String) -> URL? {
        guard let components = URLComponents(string: raw),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              components.host != nil else {
            return nil
        }
        return components.url
    }

    private var sourceLabel: String {
        guard artifact.kind == .url else { return "Note" }
        if let sourceURL = artifact.sourceURL,
           let provider = MapLinkMetadata.provider(for: sourceURL) {
            return provider.displayName
        }
        return "Link"
    }
}
