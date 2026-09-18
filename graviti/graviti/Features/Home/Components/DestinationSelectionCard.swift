import SwiftUI

struct DestinationSelectionCard: View {
    let node: OrbitNode
    let onClose: () -> Void

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
        Label("\(node.saveCount) saved items", systemImage: "square.stack")
    }
}
