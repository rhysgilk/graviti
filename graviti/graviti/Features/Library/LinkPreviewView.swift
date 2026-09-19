import SwiftUI
import LinkPresentation

struct LinkPreviewView: View {
    let url: URL

    @State private var metadata: LPLinkMetadata?
    @State private var didFinishLoading = false

    var body: some View {
        Group {
            if let metadata {
                LinkMetadataView(metadata: metadata)
                    .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 190)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(accessibilityLabel(for: metadata))
            } else {
                fallback
            }
        }
        .task(id: url) {
            metadata = nil
            didFinishLoading = false
            defer { didFinishLoading = true }
            do {
                let provider = LPMetadataProvider()
                provider.timeout = 12
                metadata = try await provider.startFetchingMetadata(for: url)
            } catch is CancellationError {
                return
            } catch {
                metadata = nil
            }
        }
    }

    private var fallback: some View {
        HStack(spacing: 14) {
            Image(systemName: didFinishLoading ? "link" : "link.badge.plus")
                .font(.title2)
                .foregroundStyle(GravitiColors.signalMint)
                .frame(width: 48, height: 48)
                .background(GravitiColors.appBackground, in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(didFinishLoading ? "Saved link" : "Loading link preview…")
                    .font(.headline)
                if let host = url.host(percentEncoded: false) {
                    Text(host.replacingOccurrences(of: "www.", with: ""))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if !didFinishLoading {
                ProgressView()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func accessibilityLabel(for metadata: LPLinkMetadata) -> String {
        let title = metadata.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = metadata.originalURL?.host(percentEncoded: false) ?? url.host(percentEncoded: false)
        return [title, host].compactMap { $0 }.joined(separator: ", ")
    }
}

private struct LinkMetadataView: UIViewRepresentable {
    let metadata: LPLinkMetadata

    func makeUIView(context: Context) -> LPLinkView {
        let view = LPLinkView(metadata: metadata)
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: LPLinkView, context: Context) {
        view.metadata = metadata
        view.isUserInteractionEnabled = false
    }
}
