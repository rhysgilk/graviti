import SwiftUI

struct DestinationSelectionCard: View {
    let node: OrbitNode
    let onClose: () -> Void
    let onOpen: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(node.level.displayName.uppercased())
                        .font(.caption.weight(.semibold))
                        .tracking(1.2)
                        .foregroundStyle(GravitiColors.signalMint)

                    Text(node.name)
                        .font(.custom("Sora-SemiBold", size: 25, relativeTo: .title2))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .accessibilityAddTraits(.isHeader)
                }

                Spacer(minLength: 0)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.10), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close destination")
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 20) {
                    statistics
                }

                VStack(alignment: .leading, spacing: 8) {
                    statistics
                }
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white.opacity(0.82))

            if let onOpen {
                Button(action: onOpen) {
                    HStack {
                        Text("See areas")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(minHeight: 44)
                    .padding(.horizontal, 14)
                    .background(GravitiColors.iris.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens smaller areas within \(node.name)")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(GravitiColors.deepInk.opacity(0.97))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(.white.opacity(0.13), lineWidth: 1)
                }
        }
    }

    @ViewBuilder
    private var statistics: some View {
        Label("\(Int(node.gravity)) Gravity", systemImage: "circle.dotted")
        Label("\(node.saveCount) saved \(node.saveCount == 1 ? "item" : "items")", systemImage: "square.stack")
    }
}
