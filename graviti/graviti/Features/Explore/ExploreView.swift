import SwiftUI

struct ExploreView: View {
    @ObservedObject var library: ArtifactLibrary
    let onFindPlace: (String) -> Void

    private var profile: InterestProfile {
        InterestProfileBuilder.build(from: library.artifacts)
    }

    private var recommendations: [DestinationRecommendation] {
        DestinationFitEngine.recommendations(from: profile, artifacts: library.artifacts)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("What draws you?")
                        .font(.custom("Sora-SemiBold", size: 28, relativeTo: .title))

                    if let leading = profile.strongestAcrossAreas {
                        leadingPattern(leading)
                    }

                    if profile.interests.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Your patterns will appear here", systemImage: "sparkles")
                                .font(.headline)
                            Text("Save places, photos, and notes to reveal interests that repeat across your Library.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                            Button("Find a place") { onFindPlace("") }
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(GravitiColors.iris, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(18)
                        .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 18))
                    } else {
                        if !recommendations.isEmpty {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Places that fit you")
                                    .font(.headline)
                                Text("Suggestions based on patterns across your Library")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            }

                            ForEach(recommendations) { recommendation in
                                NavigationLink {
                                    DestinationRecommendationView(
                                        recommendation: recommendation,
                                        onSearch: { onFindPlace(recommendation.name) }
                                    )
                                } label: {
                                    recommendationRow(recommendation)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Text("Interests across your saves")
                            .font(.headline)

                        ForEach(profile.interests) { pattern in
                            NavigationLink {
                                InterestEvidenceView(interest: pattern.name, library: library)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "sparkles")
                                        .foregroundStyle(GravitiColors.signalMint)
                                        .frame(width: 32)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(pattern.name)
                                            .font(.headline)
                                        Text(pattern.evidenceSummary)
                                            .font(.subheadline)
                                            .foregroundStyle(.white.opacity(0.68))
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white.opacity(0.45))
                                }
                                .padding(16)
                                .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                        }

                        if !profile.categories.isEmpty {
                            Text("Categories taking shape")
                                .font(.headline)
                                .padding(.top, 4)
                            ForEach(profile.categories) { pattern in
                                HStack {
                                    Text(pattern.category.displayName)
                                    Spacer()
                                    Text("\(pattern.saveCount) \(pattern.saveCount == 1 ? "save" : "saves")")
                                        .foregroundStyle(.white.opacity(0.65))
                                }
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .frame(minHeight: 48)
                                .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .background(GravitiColors.appBackground)
            .foregroundStyle(.white)
            .navigationTitle("Explore")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func recommendationRow(_ recommendation: DestinationRecommendation) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(recommendation.name)
                    .font(.headline)
                Text(recommendation.country)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
                Text(recommendation.matchedInterests.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(GravitiColors.signalMint)
                    .lineLimit(2)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(recommendation.fitPercent)%")
                    .font(.title3.weight(.bold))
                Text("FIT")
                    .font(.caption2.weight(.semibold))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.55))
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(16)
        .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(recommendation.name), \(recommendation.country), \(recommendation.fitPercent) percent fit, because of \(recommendation.matchedInterests.joined(separator: ", "))")
    }

    private func leadingPattern(_ pattern: InterestPattern) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("A pattern across places", systemImage: "circle.grid.cross")
                .font(.caption.weight(.semibold))
                .foregroundStyle(GravitiColors.signalMint)
            Text("\(pattern.name) keeps showing up")
                .font(.custom("Sora-SemiBold", size: 22, relativeTo: .title2))
            Text("You saved \(pattern.saveCount) items across \(pattern.areaCount) areas, including \(pattern.areaNames.prefix(2).joined(separator: " and ")).")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
            NavigationLink("See the saves behind this") {
                InterestEvidenceView(interest: pattern.name, library: library)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GravitiColors.iris.opacity(0.25), in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct DestinationRecommendationView: View {
    let recommendation: DestinationRecommendation
    let onSearch: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(recommendation.country.uppercased())
                        .font(.caption.weight(.semibold))
                        .tracking(1.2)
                        .foregroundStyle(GravitiColors.signalMint)
                    Text(recommendation.name)
                        .font(.custom("Sora-SemiBold", size: 30, relativeTo: .title))
                    Text("\(recommendation.fitPercent)% fit")
                        .font(.title3.weight(.semibold))
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Why it matches")
                        .font(.headline)
                    ForEach(recommendation.matchedInterests, id: \.self) { interest in
                        Label(interest, systemImage: "sparkles")
                            .foregroundStyle(GravitiColors.signalMint)
                    }
                    Text("Based on \(recommendation.supportingArtifacts.count) of your saved items across the Library.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.68))
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 18))

                Text("This is a Fit suggestion. It has no Gravity until you save something there.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.68))

                Button("Search places in \(recommendation.name)", action: onSearch)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(GravitiColors.iris, in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(20)
        }
        .background(GravitiColors.appBackground)
        .foregroundStyle(.white)
        .navigationTitle("Recommendation")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct InterestEvidenceView: View {
    let interest: String
    @ObservedObject var library: ArtifactLibrary

    private var matchingArtifacts: [Artifact] {
        library.artifacts.filter { $0.effectiveInterests.contains(interest) }
    }

    var body: some View {
        List(matchingArtifacts) { artifact in
            NavigationLink {
                SavedArtifactDetailView(artifact: artifact, library: library)
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Text(artifact.place?.name ?? artifact.originalText ?? artifact.userNote ?? "Saved item")
                        .font(.headline)
                        .lineLimit(2)
                    if let place = artifact.place {
                        Text(place.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 5)
            }
            .listRowBackground(GravitiColors.deepInk)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(GravitiColors.appBackground)
        .navigationTitle(interest)
    }
}
