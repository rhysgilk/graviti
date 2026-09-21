import SwiftUI

struct ExploreView: View {
    @ObservedObject var library: ArtifactLibrary
    let onFindPlace: (String) -> Void
    @AppStorage("explore.region") private var regionRaw = RecommendationRegion.anywhere.rawValue
    @AppStorage("explore.preferredInterests") private var preferredRaw = ""
    @AppStorage("explore.avoidedInterests") private var avoidedRaw = ""
    @AppStorage("explore.savedDestinations") private var savedDestinationsRaw = ""
    @AppStorage("explore.excludedDestinations") private var excludedDestinationsRaw = ""
    @State private var showingPreferences = false

    private var profile: InterestProfile {
        InterestProfileBuilder.build(from: library.artifacts)
    }

    private var recommendations: [DestinationRecommendation] {
        DestinationFitEngine.recommendations(from: profile, artifacts: library.artifacts, preferences: preferences)
    }

    private var preferences: ExplorePreferences {
        ExplorePreferences(
            region: RecommendationRegion(rawValue: regionRaw) ?? .anywhere,
            preferredInterests: Self.decode(preferredRaw),
            avoidedInterests: Self.decode(avoidedRaw),
            excludedDestinationIDs: excludedDestinationIDs
        )
    }

    private var savedDestinationIDs: Set<String> { Self.decode(savedDestinationsRaw) }
    private var excludedDestinationIDs: Set<String> { Self.decode(excludedDestinationsRaw) }

    private var savedGuides: [FitGuide] {
        var guides = [FitGuide]()
        for id in savedDestinationIDs {
            if let guide = DestinationFitEngine.fitGuide(for: id, from: profile, preferences: preferences) {
                guides.append(guide)
            }
        }
        return guides.sorted { $0.destination.name < $1.destination.name }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("What draws you?")
                        .font(.custom("Sora-SemiBold", size: 28, relativeTo: .title))

                    Button { showingPreferences = true } label: {
                        HStack {
                            Label(preferenceSummary, systemImage: "slider.horizontal.3")
                            Spacer()
                            Text("Tune")
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                        .padding(14)
                        .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)

                    if let leading = profile.strongestAcrossAreas {
                        leadingPattern(leading)
                    }

                    if !savedGuides.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Your Fit Guides")
                                .font(.headline)
                            ForEach(savedGuides) { guide in
                                NavigationLink {
                                    FitGuideView(
                                        guide: guide,
                                        library: library,
                                        provider: MapKitPlaceSearchProvider(),
                                        onKeepGuide: {}
                                    )
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "bookmark.fill")
                                            .foregroundStyle(GravitiColors.signalMint)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(guide.destination.name).font(.headline)
                                            Text("\(guide.destination.country) · \(GravitiCopy.savedItems(library.artifacts.filter(guide.contains).count))")
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.62))
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.white.opacity(0.55))
                                    }
                                    .padding(14)
                                    .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 14))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if profile.interests.isEmpty && recommendations.isEmpty {
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
                        if recommendations.isEmpty && hasActivePreferences {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("No destinations match every filter", systemImage: "line.3.horizontal.decrease.circle")
                                    .font(.headline)
                                Text("Try another region or remove an avoid rule. Your saved-interest patterns are still shown below.")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.68))
                                Button("Change preferences") { showingPreferences = true }
                                    .font(.subheadline.weight(.semibold))
                            }
                            .padding(18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 18))
                        } else if !recommendations.isEmpty {
                            Text("Fit")
                                .font(.headline)

                            ForEach(recommendations) { recommendation in
                                NavigationLink {
                                    DestinationRecommendationView(
                                        recommendation: recommendation,
                                        isSaved: savedDestinationIDs.contains(recommendation.id),
                                        library: library,
                                        onSave: { saveDestination(recommendation) },
                                        onNotForMe: { excludeDestination(recommendation) }
                                    )
                                } label: {
                                    recommendationRow(recommendation)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if !profile.interests.isEmpty {
                            Text("Interests")
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
                                            Text(InterestDisplayName.localized(pattern.name))
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
                        }

                        if !profile.categories.isEmpty {
                            Text("Categories")
                                .font(.headline)
                                .padding(.top, 4)
                            ForEach(profile.categories) { pattern in
                                HStack {
                                    Text(pattern.category.displayName)
                                    Spacer()
                                    Text(GravitiCopy.saves(pattern.saveCount))
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
            .sheet(isPresented: $showingPreferences) {
                ExplorePreferencesView(
                    regionRaw: $regionRaw,
                    preferredRaw: $preferredRaw,
                    avoidedRaw: $avoidedRaw
                )
            }
        }
    }

    private var preferenceSummary: String {
        let region = preferences.region.displayName
        let selected = preferences.preferredInterests.count + preferences.avoidedInterests.count
        return selected == 0 && preferences.region == .anywhere
            ? String(localized: "Anywhere · Based on your saves")
            : "\(region) · \(GravitiCopy.preferences(selected))"
    }

    private var hasActivePreferences: Bool {
        preferences.region != .anywhere || !preferences.preferredInterests.isEmpty || !preferences.avoidedInterests.isEmpty
    }

    private static func decode(_ raw: String) -> Set<String> {
        Set(raw.split(separator: "|").map(String.init))
    }

    private func recommendationRow(_ recommendation: DestinationRecommendation) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(recommendation.name)
                    .font(.headline)
                Text(recommendation.country)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
                Text(InterestDisplayName.joined(recommendation.matchedInterests))
                    .font(.caption)
                    .foregroundStyle(GravitiColors.signalMint)
                    .lineLimit(2)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if savedDestinationIDs.contains(recommendation.id) {
                    Image(systemName: "bookmark.fill")
                        .foregroundStyle(GravitiColors.signalMint)
                }
                Text(recommendation.scoreLabel)
                    .font(recommendation.confidence == .early ? .caption.weight(.bold) : .title3.weight(.bold))
                Text(recommendation.confidence == .early
                     ? String(localized: "MORE SAVES NEEDED")
                     : recommendation.confidence.displayName.uppercased())
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
        .accessibilityLabel("\(recommendation.name), \(recommendation.country), \(recommendation.scoreLabel), \(recommendation.confidence.displayName), based on \(InterestDisplayName.joined(recommendation.matchedInterests, separator: ", "))")
    }

    private func leadingPattern(_ pattern: InterestPattern) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Pattern", systemImage: "circle.grid.cross")
                .font(.caption.weight(.semibold))
                .foregroundStyle(GravitiColors.signalMint)
            Text("\(InterestDisplayName.localized(pattern.name)) keeps showing up")
                .font(.custom("Sora-SemiBold", size: 22, relativeTo: .title2))
            Text("You saved \(pattern.saveCount) items across \(pattern.areaCount) areas, including \(ListFormatter.localizedString(byJoining: Array(pattern.areaNames.prefix(2)))).")
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

    private func saveDestination(_ recommendation: DestinationRecommendation) {
        var saved = savedDestinationIDs
        var excluded = excludedDestinationIDs
        saved.insert(recommendation.id)
        excluded.remove(recommendation.id)
        savedDestinationsRaw = Self.encode(saved)
        excludedDestinationsRaw = Self.encode(excluded)
    }

    private func excludeDestination(_ recommendation: DestinationRecommendation) {
        var saved = savedDestinationIDs
        var excluded = excludedDestinationIDs
        saved.remove(recommendation.id)
        excluded.insert(recommendation.id)
        savedDestinationsRaw = Self.encode(saved)
        excludedDestinationsRaw = Self.encode(excluded)
    }

    private static func encode(_ values: Set<String>) -> String {
        values.sorted().joined(separator: "|")
    }
}

private struct DestinationRecommendationView: View {
    @Environment(\.dismiss) private var dismiss
    let recommendation: DestinationRecommendation
    let isSaved: Bool
    @ObservedObject var library: ArtifactLibrary
    let onSave: () -> Void
    let onNotForMe: () -> Void

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
                    Text(recommendation.scoreLabel)
                        .font(.title3.weight(.semibold))
                    Text("\(recommendation.confidence.displayName) · \(recommendation.confidencePercent)% evidence confidence")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.68))
                    Text("Destination knowledge · \(recommendation.knowledgeConfidencePercent)% reviewed confidence")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.58))
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Patterns")
                        .font(.headline)
                    ForEach(recommendation.matchedInterests, id: \.self) { interest in
                        Label(InterestDisplayName.localized(interest), systemImage: "sparkles")
                            .foregroundStyle(GravitiColors.signalMint)
                    }
                    Text("Based on \(recommendation.supportingArtifacts.count) of your saved items across the Library.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.68))
                    if recommendation.confidence == .early {
                        Text("This is an early signal. More detailed saves from distinct places will make it more reliable.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.68))
                    }
                    if !recommendation.explicitMatches.isEmpty {
                        Text("Also matches what you asked for: \(recommendation.explicitMatches.joined(separator: ", ")).")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.68))
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 18))

                if !recommendation.knowledgeSources.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Destination sources")
                            .font(.headline)
                        Text("These reviewed sources support what Graviti knows about this destination. They do not determine your personal fit by themselves.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.68))
                        ForEach(recommendation.knowledgeSources) { source in
                            Link(destination: source.url) {
                                Label(source.title, systemImage: "arrow.up.right.square")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(GravitiColors.signalMint)
                            }
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 18))
                }

                NavigationLink {
                    FitGuideView(
                        guide: FitGuide(
                            destination: DestinationFitEngine.savedDestination(for: recommendation.id) ?? SavedDestination(
                                name: recommendation.name,
                                country: recommendation.country
                            ),
                            interests: recommendation.matchedInterests
                        ),
                        library: library,
                        provider: MapKitPlaceSearchProvider(),
                        onKeepGuide: onSave
                    )
                } label: {
                    Label("Build my \(recommendation.name) Fit Guide", systemImage: "map.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(GravitiColors.iris, in: RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    onSave()
                } label: {
                    Label(isSaved ? "Destination saved" : "Save destination", systemImage: isSaved ? "bookmark.fill" : "bookmark")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isSaved)

                Button(role: .destructive) {
                    onNotForMe()
                    dismiss()
                } label: {
                    Label("Not for me", systemImage: "hand.thumbsdown")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
            }
            .padding(20)
        }
        .background(GravitiColors.appBackground)
        .foregroundStyle(.white)
        .navigationTitle("Recommendation")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ExplorePreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var regionRaw: String
    @Binding var preferredRaw: String
    @Binding var avoidedRaw: String

    private let interests = ["Matcha", "Tea", "Coffee", "Desserts", "Seafood", "Scenic views", "Hiking", "Forests", "Mountains", "National parks", "Nature", "Beaches", "Coast & water", "Architecture", "History", "Museums", "Gardens", "Shopping", "Wildlife"]

    private var preferred: Set<String> { decode(preferredRaw) }
    private var avoided: Set<String> { decode(avoidedRaw) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Where") {
                    Picker("Region", selection: $regionRaw) {
                        ForEach(RecommendationRegion.allCases) { region in
                            Text(region.displayName).tag(region.rawValue)
                        }
                    }
                }
                Section("I want more of") {
                    ForEach(interests, id: \.self) { interest in
                        selectionRow(interest, selected: preferred.contains(interest)) {
                            togglePreferred(interest)
                        }
                    }
                }
                Section("Avoid") {
                    ForEach(interests, id: \.self) { interest in
                        selectionRow(interest, selected: avoided.contains(interest)) {
                            toggleAvoided(interest)
                        }
                    }
                }
                Section {
                    Button("Reset preferences", role: .destructive) {
                        regionRaw = RecommendationRegion.anywhere.rawValue
                        preferredRaw = ""
                        avoidedRaw = ""
                    }
                }
            }
            .navigationTitle("Tune Explore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func selectionRow(_ interest: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(InterestDisplayName.localized(interest))
                    .foregroundStyle(.primary)
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(GravitiColors.iris)
                }
            }
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func togglePreferred(_ interest: String) {
        var target = preferred
        var other = avoided
        if target.contains(interest) {
            target.remove(interest)
        } else {
            target.insert(interest)
            other.remove(interest)
        }
        preferredRaw = encode(target)
        avoidedRaw = encode(other)
    }

    private func toggleAvoided(_ interest: String) {
        var target = avoided
        var other = preferred
        if target.contains(interest) {
            target.remove(interest)
        } else {
            target.insert(interest)
            other.remove(interest)
        }
        avoidedRaw = encode(target)
        preferredRaw = encode(other)
    }

    private func decode(_ raw: String) -> Set<String> {
        Set(raw.split(separator: "|").map(String.init))
    }

    private func encode(_ values: Set<String>) -> String {
        values.sorted().joined(separator: "|")
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
                    Text(artifact.place?.name ?? artifact.originalText ?? artifact.userNote ?? String(localized: "Saved item"))
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
        .navigationTitle(InterestDisplayName.localized(interest))
    }
}
