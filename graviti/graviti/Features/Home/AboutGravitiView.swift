import SwiftUI
import UIKit

struct AboutGravitiView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var library: ArtifactLibrary
    @State private var copiedDiagnostics = false

    private var diagnostics: AppDiagnosticsReport {
        AppDiagnosticsReport(
            artifacts: library.artifacts,
            appVersion: appVersion,
            buildNumber: buildNumber,
            operatingSystem: "iOS \(UIDevice.current.systemVersion)",
            deviceFamily: UIDevice.current.model
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 10) {
                        GravitiWordmark(size: .small, animated: false)
                        Text("Save what pulls you. Graviti turns a private collection of travel inspiration into patterns, destination Fit, and places you can act on.")
                            .font(GravitiTypography.subheadline)
                            .foregroundStyle(.white.opacity(0.72))
                    }

                    aboutSection(
                        title: "Private by default",
                        symbol: "lock.shield.fill",
                        detail: "Your Library stays on this device. Graviti has no account, advertising SDK, analytics SDK, or Graviti-operated sync server."
                    )
                    aboutSection(
                        title: "Backups are yours",
                        symbol: "externaldrive.fill",
                        detail: "Library Actions can export a versioned backup with saved media and recommendation preferences. Deleting the app removes local data unless you export a backup first."
                    )
                    aboutSection(
                        title: "When the app connects",
                        symbol: "network",
                        detail: "Apple MapKit powers place search and Fit Guide suggestions. Public map collections and saved webpages are contacted only for features you invoke or eligible links you save. Photo text recognition runs on device."
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Feedback & support")
                            .font(GravitiTypography.headline)

                        if let feedbackURL {
                            Link(destination: feedbackURL) {
                                actionLabel("Send feedback", symbol: "bubble.left.and.bubble.right", trailingSymbol: "arrow.up.right")
                            }
                        }

                        Button {
                            UIPasteboard.general.string = diagnostics.text
                            copiedDiagnostics = true
                        } label: {
                            actionLabel(
                                copiedDiagnostics ? "Diagnostics copied" : "Copy diagnostics",
                                symbol: copiedDiagnostics ? "checkmark.circle.fill" : "doc.on.doc",
                                trailingSymbol: copiedDiagnostics ? "checkmark" : "doc.on.doc"
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Copies app and aggregate status details without saved content")

                        if let privacyURL = URL(string: "https://github.com/rhysgilk/graviti/blob/main/docs/PRIVACY.md") {
                            Link(destination: privacyURL) {
                                actionLabel("View privacy policy", symbol: "doc.text", trailingSymbol: "arrow.up.right")
                            }
                        }

                        Text("Feedback opens the public GitHub issue tracker. Do not include private or sensitive information. Diagnostics contain aggregate counts and app details only.")
                            .font(GravitiTypography.caption)
                            .foregroundStyle(.white.opacity(0.62))
                    }

                    Text("Version \(appVersion) (\(buildNumber))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(GravitiColors.appBackground)
            .foregroundStyle(.white)
            .navigationTitle("About Graviti")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func aboutSection(title: LocalizedStringKey, symbol: String, detail: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol)
                .font(GravitiTypography.headline)
            Text(detail)
                .font(GravitiTypography.body)
                .foregroundStyle(.white.opacity(0.72))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 16))
    }

    private func actionLabel(_ title: LocalizedStringKey, symbol: String, trailingSymbol: String) -> some View {
        Label {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: trailingSymbol)
                    .accessibilityHidden(true)
            }
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(GravitiColors.signalMint)
        }
        .font(GravitiTypography.subheadlineSemibold)
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
        .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 14))
    }

    private var feedbackURL: URL? {
        var components = URLComponents(string: "https://github.com/rhysgilk/graviti/issues/new")
        components?.queryItems = [URLQueryItem(name: "title", value: "Graviti feedback: ")]
        return components?.url
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }
}
