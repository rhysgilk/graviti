import SwiftUI

struct DataPrivacyView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var library: ArtifactLibrary
    @AppStorage("recommendation.feedback.v1") private var feedbackJSON = ""
    @AppStorage("recommendation.outcomes.v1") private var outcomesJSON = ""
    @State private var showingFeedback = false
    @State private var showingOutcomes = false
    @State private var confirmingSampleRemoval = false
    @State private var sampleRemovalError: String?

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
                        detail: "You can edit inferred details, remove place matches, review recommendation feedback, and delete individual or multiple saves. Graviti has no advertising or analytics SDK in this beta."
                    )

                    Button { showingFeedback = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "hand.thumbsup.fill")
                                .foregroundStyle(GravitiColors.signalMint)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Recommendation feedback")
                                    .font(.headline)
                                Text(feedbackSummary)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.68))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)

                    Button { showingOutcomes = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundStyle(GravitiColors.signalMint)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Recommendation activity")
                                    .font(.headline)
                                Text(outcomeSummary)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.68))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)

                    if library.hasSampleLibrary {
                        Button(role: .destructive) { confirmingSampleRemoval = true } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "sparkles.rectangle.stack.fill")
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Remove sample library").font(.headline)
                                    Text("Deletes only the clearly labeled sample saves. Your own saves stay in place.")
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.68))
                                }
                                Spacer()
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    }

                    if let sampleRemovalError {
                        Text(sampleRemovalError)
                            .font(.caption)
                            .foregroundStyle(GravitiColors.opportunityCoral)
                    }

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

                    Text("GitHub support requests are public. Do not include private or sensitive information.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))

                    Text("Version \(appVersion) (\(buildNumber))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .sheet(isPresented: $showingFeedback) {
                RecommendationFeedbackHistoryView(feedbackJSON: $feedbackJSON)
            }
            .sheet(isPresented: $showingOutcomes) {
                RecommendationOutcomeHistoryView(outcomesJSON: $outcomesJSON)
            }
            .confirmationDialog(
                "Remove the sample library?",
                isPresented: $confirmingSampleRemoval,
                titleVisibility: .visible
            ) {
                Button("Remove samples", role: .destructive) {
                    Task {
                        do { _ = try await library.removeSampleLibrary() }
                        catch { sampleRemovalError = error.localizedDescription }
                    }
                }
            } message: {
                Text("Your own saves, guides, and preferences will not be removed.")
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

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    private var feedbackSummary: String {
        let count = RecommendationFeedbackStore.decode(feedbackJSON).count
        return count == 0
            ? String(localized: "No responses recorded yet")
            : String(localized: "\(count) local responses · View, change, or remove")
    }

    private var outcomeSummary: String {
        let count = RecommendationOutcomeStore.decode(outcomesJSON).count
        return count == 0
            ? String(localized: "No activity recorded yet")
            : String(localized: "\(count) local events · Inspect or remove")
    }
}

private struct RecommendationOutcomeHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var outcomesJSON: String
    @State private var confirmingClear = false

    private var events: [RecommendationOutcomeEvent] {
        RecommendationOutcomeStore.decode(outcomesJSON).sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            Group {
                if events.isEmpty {
                    ContentUnavailableView(
                        "No recommendation activity",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("Shown, opened, saved, dismissed, and visit outcomes will appear here.")
                    )
                } else {
                    List {
                        ForEach(events) { event in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Label(event.kind.displayName, systemImage: event.kind.symbol)
                                        .font(GravitiTypography.captionSemibold)
                                        .foregroundStyle(GravitiColors.signalMint)
                                    Spacer()
                                    Text(event.createdAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Text(event.destinationName).font(GravitiTypography.headline)
                                if event.kind != .suggestedPlaceSaved {
                                    Text("\(event.score) FIT · \(event.confidencePercent)% confidence")
                                        .font(GravitiTypography.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                            .swipeActions {
                                Button(role: .destructive) {
                                    outcomesJSON = RecommendationOutcomeStore.removing(event.id, from: outcomesJSON)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(GravitiColors.appBackground)
            .navigationTitle("Recommendation Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                if !events.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear", role: .destructive) { confirmingClear = true }
                    }
                }
            }
            .confirmationDialog("Clear recommendation activity?", isPresented: $confirmingClear) {
                Button("Clear all activity", role: .destructive) {
                    outcomesJSON = RecommendationOutcomeStore.removingAll()
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct RecommendationFeedbackHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var feedbackJSON: String
    @State private var confirmingClear = false

    private var events: [RecommendationFeedbackEvent] {
        RecommendationFeedbackStore.decode(feedbackJSON).sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            Group {
                if events.isEmpty {
                    ContentUnavailableView(
                        "No recommendation feedback",
                        systemImage: "hand.thumbsup",
                        description: Text("Responses to occasional Fit questions will stay on this device and appear here.")
                    )
                } else {
                    List {
                        Section {
                            ForEach(events) { event in
                                feedbackRow(event)
                                    .swipeActions {
                                        Button(role: .destructive) {
                                            feedbackJSON = RecommendationFeedbackStore.removing(event.id, from: feedbackJSON)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        } footer: {
                            Text("This history stays on this device. Changing a response preserves when and where the question was asked.")
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(GravitiColors.appBackground)
            .navigationTitle("Recommendation Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if !events.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear", role: .destructive) { confirmingClear = true }
                    }
                }
            }
            .confirmationDialog(
                "Clear all recommendation feedback?",
                isPresented: $confirmingClear,
                titleVisibility: .visible
            ) {
                Button("Clear all feedback", role: .destructive) {
                    feedbackJSON = RecommendationFeedbackStore.removingAll()
                }
            } message: {
                Text("This removes every saved response from this device.")
            }
        }
        .preferredColorScheme(.dark)
    }

    private func feedbackRow(_ event: RecommendationFeedbackEvent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(event.prompt)
                .font(.headline)
            HStack {
                Menu {
                    ForEach(RecommendationFeedbackResponse.allCases, id: \.self) { response in
                        Button {
                            feedbackJSON = RecommendationFeedbackStore.replacingResponse(
                                for: event.id,
                                with: response,
                                in: feedbackJSON
                            )
                        } label: {
                            Label(response.displayName, systemImage: response.symbol)
                        }
                    }
                } label: {
                    Label(event.response.displayName, systemImage: event.response.symbol)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(GravitiColors.signalMint)
                }
                Spacer()
                Text(event.createdAt, format: .dateTime.month(.abbreviated).day().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(event.recommendationID)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.prompt), response \(event.response.displayName)")
    }
}

#Preview {
    DataPrivacyView(library: ArtifactLibrary(repository: PreviewArtifactRepository()))
}
