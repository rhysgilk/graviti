import SwiftUI

struct DataPrivacyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Label {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Stored on this device")
                                .font(.title3.weight(.semibold))
                            Text("Your Library does not require an account and does not sync to a Graviti server.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "lock.shield.fill")
                            .font(.title2)
                            .foregroundStyle(GravitiColors.signalMint)
                    }

                    privacySection(
                        title: "When Graviti connects",
                        symbol: "network",
                        detail: "Place search and resolution use Apple MapKit. Saved public links may be contacted to fetch a title, description, and preview image. On-device Vision reads photo text without uploading the image for recognition."
                    )

                    privacySection(
                        title: "Back up before uninstalling",
                        symbol: "externaldrive.fill",
                        detail: "Deleting Graviti also removes its local Library. Use Export backup from Library Actions to keep a copy, including saved photos, and Restore backup to bring it back later."
                    )

                    privacySection(
                        title: "You stay in control",
                        symbol: "slider.horizontal.3",
                        detail: "You can edit inferred details, remove place matches, and delete individual or multiple saves. Graviti has no advertising or analytics SDK in this beta."
                    )

                    VStack(spacing: 10) {
                        if let privacyPolicyURL = URL(string: "https://github.com/rhysgilk/graviti/blob/main/docs/PRIVACY.md") {
                            Link(destination: privacyPolicyURL) {
                                privacyLinkLabel("View full privacy policy", symbol: "doc.text")
                            }
                        }

                        if let supportURL = URL(string: "https://github.com/rhysgilk/graviti/issues") {
                            Link(destination: supportURL) {
                                privacyLinkLabel("Get support", symbol: "questionmark.circle")
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .background(GravitiColors.appBackground)
            .navigationTitle("Data & Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func privacySection(title: LocalizedStringKey, symbol: String, detail: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol)
                .font(.headline)
            Text(detail)
                .font(.body)
                .foregroundStyle(.white.opacity(0.72))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 16))
    }

    private func privacyLinkLabel(_ title: LocalizedStringKey, symbol: String) -> some View {
        Label {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .accessibilityHidden(true)
            }
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(GravitiColors.signalMint)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
        .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    DataPrivacyView()
}
