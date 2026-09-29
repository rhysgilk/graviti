import SwiftUI

struct OnboardingView: View {
    let onFindPlace: () -> Void
    let onSaveOrImport: () -> Void
    let onTrySampleLibrary: () async throws -> Void
    let onExplore: () -> Void

    @State private var page = 0
    @State private var isAddingSamples = false
    @State private var sampleError: String?

    var body: some View {
        ZStack {
            GravitiColors.appBackground.ignoresSafeArea()
            VStack(spacing: 14) {
                GravitiWordmark(size: .large, animated: true)
                    .padding(.top, 26)
                TabView(selection: $page) {
                    intro.tag(0)
                    detectionDemo.tag(1)
                    valueDemo.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .animation(.easeInOut(duration: 0.25), value: page)
                if let sampleError {
                    Text(sampleError)
                        .font(GravitiTypography.caption)
                        .foregroundStyle(GravitiColors.opportunityCoral)
                        .multilineTextAlignment(.center)
                }
                primaryActions
                    .padding(.horizontal, 24)
                    .padding(.bottom, 18)
            }
        }
        .foregroundStyle(.white)
        .font(GravitiTypography.body)
    }

    private var intro: some View {
        onboardingPage(
            eyebrow: "A home for places",
            title: "Save what pulls you.",
            detail: "Bring in places, Maps lists, social links, screenshots, photos, and notes. Graviti keeps the source while it finds the place and fills in details.",
            symbol: "square.and.arrow.down.fill"
        ) {
            VStack(spacing: 12) {
                feature(icon: "bolt.fill", title: "Save first", detail: "Keep moving while details finish in the background.")
                feature(icon: "lock.shield.fill", title: "Private by default", detail: "Your Library stays on this device and can be backed up.")
            }
        }
    }

    private var detectionDemo: some View {
        onboardingPage(
            eyebrow: "From save to signal",
            title: "See what Graviti notices.",
            detail: "A save becomes more useful as its place, category, interests, and your reason for saving it come together.",
            symbol: "sparkles"
        ) {
            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 12) {
                    Image(systemName: "mountain.2.fill")
                        .font(.title2)
                        .foregroundStyle(GravitiColors.signalMint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Acadia National Park").font(GravitiTypography.headline)
                        Text("Bar Harbor, Maine").font(GravitiTypography.caption).foregroundStyle(.secondary)
                    }
                }
                Text("“Rocky coastline and quiet sunrise trails”")
                    .font(GravitiTypography.subheadline)
                HStack {
                    interestChip("National parks")
                    interestChip("Coast & water")
                    interestChip("Hiking")
                }
            }
            .padding(16)
            .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 18))
        }
    }

    private var valueDemo: some View {
        onboardingPage(
            eyebrow: "Your patterns become plans",
            title: "Let your saves point somewhere.",
            detail: "Gravity shows where your attention gathers. Fit combines interests, evidence, and confidence. Fit Guides turn a destination into specific places you can shortlist.",
            symbol: "circle.grid.cross.fill"
        ) {
            VStack(spacing: 12) {
                feature(icon: "globe.americas.fill", title: "Gravity", detail: "Destinations grow from your actual saves.")
                feature(icon: "scope", title: "Fit", detail: "Recommendations explain the patterns and confidence behind them.")
                feature(icon: "book.closed.fill", title: "Fit Guides", detail: "Collect matching museums, scenery, food, and more.")
            }
        }
    }

    private func onboardingPage<Content: View>(
        eyebrow: LocalizedStringKey,
        title: LocalizedStringKey,
        detail: LocalizedStringKey,
        symbol: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView {
            VStack(spacing: 22) {
                Image(systemName: symbol)
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(GravitiColors.signalMint)
                    .frame(width: 84, height: 84)
                    .background(GravitiColors.deepInk, in: Circle())
                VStack(spacing: 9) {
                    Text(eyebrow)
                        .font(GravitiTypography.captionSemibold)
                        .foregroundStyle(GravitiColors.signalMint)
                        .textCase(.uppercase)
                    Text(title)
                        .font(.custom("Sora-SemiBold", size: 28, relativeTo: .title))
                        .multilineTextAlignment(.center)
                    Text(detail)
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                }
                content()
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 42)
        }
    }

    @ViewBuilder
    private var primaryActions: some View {
        if page < 2 {
            Button("Continue") { page += 1 }
                .primaryOnboardingButton()
            Button("Skip") { onExplore() }
                .frame(minHeight: 42)
        } else {
            Button("Find your first place", action: onFindPlace)
                .primaryOnboardingButton()
            HStack(spacing: 10) {
                Button("Save or import", action: onSaveOrImport)
                    .secondaryOnboardingButton()
                Button {
                    addSamples()
                } label: {
                    if isAddingSamples { ProgressView().frame(maxWidth: .infinity) }
                    else { Text("Try sample library").frame(maxWidth: .infinity) }
                }
                .secondaryOnboardingButton()
                .disabled(isAddingSamples)
            }
            Button("Explore without samples", action: onExplore)
                .frame(minHeight: 42)
        }
    }

    private func addSamples() {
        isAddingSamples = true
        sampleError = nil
        Task {
            do {
                try await onTrySampleLibrary()
            } catch {
                sampleError = error.localizedDescription
                isAddingSamples = false
            }
        }
    }

    private func feature(icon: String, title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .foregroundStyle(GravitiColors.signalMint)
                .frame(width: 34, height: 34)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(GravitiTypography.headline)
                Text(detail).font(GravitiTypography.subheadline).foregroundStyle(.white.opacity(0.68))
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func interestChip(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(GravitiTypography.captionSemibold)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(GravitiColors.iris.opacity(0.24), in: Capsule())
    }
}

private extension View {
    func primaryOnboardingButton() -> some View {
        font(GravitiTypography.headline)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(GravitiColors.iris, in: RoundedRectangle(cornerRadius: 15))
            .buttonStyle(.plain)
    }

    func secondaryOnboardingButton() -> some View {
        font(GravitiTypography.captionSemibold)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 15))
            .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingView(onFindPlace: {}, onSaveOrImport: {}, onTrySampleLibrary: {}, onExplore: {})
}
