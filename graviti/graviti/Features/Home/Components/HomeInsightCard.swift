import SwiftUI

struct HomeInsightCard: View {
    let insight: HomeInsight
    let position: Int
    let total: Int
    let onClose: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onViewDestination: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(insight.eyebrow)
                        .font(.caption.weight(.semibold))
                        .tracking(1.2)
                        .foregroundStyle(GravitiColors.signalMint)

                    Text(insight.title)
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

            Text(insight.detail)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    navigation
                    Spacer(minLength: 0)
                    viewButton
                }

                VStack(alignment: .leading, spacing: 8) {
                    navigation
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

    @ViewBuilder
    private var navigation: some View {
        if total > 1 {
            HStack(spacing: 4) {
                Button(action: onPrevious) {
                    Image(systemName: "chevron.backward")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Previous insight")

                Text("\(position) of \(total)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.65))
                    .frame(minWidth: 44)

                Button(action: onNext) {
                    Image(systemName: "chevron.forward")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Next insight")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
        }
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
        .accessibilityLabel("View \(insight.destination.name)")
    }
}
