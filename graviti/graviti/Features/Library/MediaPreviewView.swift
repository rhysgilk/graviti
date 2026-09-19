import SwiftUI
import ImageIO

struct MediaPreviewView: View {
    let mediaKey: String
    let maximumPixelSize: Int
    var minimumHeight: CGFloat = 200

    @State private var preview: UIImage?
    @State private var finishedLoading = false

    var body: some View {
        Group {
            if let preview {
                Image(uiImage: preview)
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel("Saved photo")
            } else if finishedLoading {
                Label("Photo unavailable", systemImage: "photo.badge.exclamationmark")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: minimumHeight)
            } else {
                ProgressView("Loading photo")
                    .frame(maxWidth: .infinity, minHeight: minimumHeight)
            }
        }
        .task(id: mediaKey) {
            preview = nil
            finishedLoading = false
            defer { finishedLoading = true }
            guard let url = try? SharedMediaStore.url(for: mediaKey),
                  let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize
            ]
            if let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
                preview = UIImage(cgImage: image)
            }
        }
    }
}
