import SwiftUI

struct HomeInsightCard: View {
    let insight: HomeInsight
    let onClose: () -> Void
    let onViewDestination: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(insight.destinationCount) destinations")
                        .font(.caption.weight(.semibold))
                        .tracking(1.2)
                        .foregroundStyle(GravitiColors.signalMint)

                    Text("\(insight.leadingDestination.name) leads your field")
                        .font(.custom("Sora-SemiBold", size: 19, relativeTo: .headline))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
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
                .accessibilityLabel("Close field insight")
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    statistics.fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 0)
                    viewButton
                }

                VStack(alignment: .leading, spacing: 8) {
                    statistics
                    viewButton
                }
            }
        }
        .padding(16)
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

    private var statistics: some View {
        Text("\(Int(insight.leadingDestination.gravity)) Gravity · \(insight.leadingDestination.saveCount) saved items")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white.opacity(0.82))
    }

    private var viewButton: some View {
        Button(action: onViewDestination) {
            Label("View", systemImage: "arrow.up.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(minWidth: 44, minHeight: 44)
                .padding(.horizontal, 10)
                .background(GravitiColors.iris.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("View \(insight.leadingDestination.name)")
    }
}
