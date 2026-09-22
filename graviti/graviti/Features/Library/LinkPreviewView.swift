import SwiftUI
import LinkPresentation
import UIKit

struct LinkPreviewView: View {
    let url: URL
    let cachedMetadata: ArtifactLinkMetadata?
    let onRetry: () async -> Void

    @State private var metadata: LPLinkMetadata?
    @State private var didFinishLoading = false
    @State private var attempt = 0

    var body: some View {
        Group {
            if let cachedMetadata {
                CachedLinkMetadataView(metadata: cachedMetadata)
            } else if let metadata {
                LinkMetadataView(metadata: metadata)
                    .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 190)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(accessibilityLabel(for: metadata))
            } else {
                fallback
            }
        }
        .task(id: "\(url.absoluteString)#\(attempt)") {
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
            Image(systemName: didFinishLoading ? "wifi.exclamationmark" : "link.badge.plus")
                .font(.title2)
                .foregroundStyle(GravitiColors.signalMint)
                .frame(width: 48, height: 48)
                .background(GravitiColors.appBackground, in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(didFinishLoading ? "Preview unavailable" : "Loading link preview…")
                    .font(.headline)
                if didFinishLoading {
                    Text("The saved link is still available. Check your connection and try the preview again.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let host = url.host(percentEncoded: false) {
                    Text(host.replacingOccurrences(of: "www.", with: ""))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if !didFinishLoading {
                ProgressView()
            } else {
                Button("Retry") {
                    attempt += 1
                    Task { await onRetry() }
                }
                .font(.caption.weight(.semibold))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private func accessibilityLabel(for metadata: LPLinkMetadata) -> String {
        let title = metadata.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = metadata.originalURL?.host(percentEncoded: false) ?? url.host(percentEncoded: false)
        return [title, host].compactMap { $0 }.joined(separator: ", ")
    }
}

private struct CachedLinkMetadataView: View {
    let metadata: ArtifactLinkMetadata

    var body: some View {
        HStack(spacing: 14) {
            if let data = metadata.imageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 104, height: 104)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Image(systemName: "link")
                    .font(.title2)
                    .foregroundStyle(GravitiColors.signalMint)
                    .frame(width: 56, height: 56)
                    .background(GravitiColors.appBackground, in: RoundedRectangle(cornerRadius: 12))
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(metadata.siteName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GravitiColors.signalMint)
                if let title = metadata.title {
                    Text(title).font(.headline).lineLimit(2)
                }
                if let summary = metadata.summary {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.68))
                        .lineLimit(3)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
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
