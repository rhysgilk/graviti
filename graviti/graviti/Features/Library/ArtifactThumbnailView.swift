import SwiftUI
import UIKit

struct ArtifactThumbnailView: View {
    let artifact: Artifact
    var size: CGFloat = 72

    var body: some View {
        Group {
            if let mediaKey = artifact.mediaKey {
                MediaPreviewView(
                    mediaKey: mediaKey,
                    maximumPixelSize: Int(size * 3),
                    minimumHeight: size,
                    contentMode: .fill
                )
            } else if let data = artifact.linkMetadata?.imageData,
                      let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .background(GravitiColors.appBackground)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityHidden(true)
    }

    private var fallback: some View {
        ZStack {
            LinearGradient(
                colors: [GravitiColors.iris.opacity(0.38), GravitiColors.deepInk],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: iconName)
                .font(.title2.weight(.medium))
                .foregroundStyle(GravitiColors.signalMint)
        }
    }

    private var iconName: String {
        switch artifact.kind {
        case .url: "link"
        case .manual: "note.text"
        case .photo: "photo"
        }
    }
}
