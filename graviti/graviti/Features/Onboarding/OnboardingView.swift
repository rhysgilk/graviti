import SwiftUI

struct OnboardingView: View {
    let onFindPlace: () -> Void
    let onSaveOrImport: () -> Void
    let onExplore: () -> Void

    var body: some View {
        ZStack {
            GravitiColors.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 30) {
                    GravitiWordmark(size: .large, animated: true)
                        .padding(.top, 38)

                    VStack(spacing: 10) {
                        Text("Save what pulls you.")
                            .font(.custom("Sora-SemiBold", size: 28, relativeTo: .title))
                            .multilineTextAlignment(.center)
                        Text("Graviti organizes the places that catch your attention, learns the interests behind them, and helps reveal where you may want to go next.")
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.72))
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 14) {
                        feature(
                            icon: "square.and.arrow.down",
                            title: "Save anything",
                            detail: "Places, Maps links, photos, screenshots, and notes."
                        )
                        feature(
                            icon: "circle.grid.cross",
                            title: "Watch Gravity build",
                            detail: "Destinations grow as your real saves accumulate."
                        )
                        feature(
                            icon: "sparkles",
                            title: "Discover deeper patterns",
                            detail: "Repeated interests across places shape future recommendations."
                        )
                        feature(
                            icon: "lock.shield",
                            title: "Private by default",
                            detail: "Your Library stays on this device. Export a backup whenever you want."
                        )
                    }

                    VStack(spacing: 12) {
                        Button("Find your first place", action: onFindPlace)
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(GravitiColors.iris, in: RoundedRectangle(cornerRadius: 15))

                        Button("Save or import something", action: onSaveOrImport)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 15))

                        Button("Explore the app", action: onExplore)
                            .font(.subheadline.weight(.semibold))
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
        }
        .foregroundStyle(.white)
    }

    private func feature(icon: String, title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(GravitiColors.signalMint)
                .frame(width: 44, height: 44)
                .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 13))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.68))
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    OnboardingView(onFindPlace: {}, onSaveOrImport: {}, onExplore: {})
}
