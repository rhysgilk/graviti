import Foundation

struct LibrarySearchResults {
    let artifacts: [Artifact]
    let destinations: [OrbitNode]
    let interests: [InterestPattern]
    let places: [SavedPlace]
}

enum LibrarySearchEngine {
    static func search(
        _ query: String,
        in artifacts: [Artifact],
        limit: Int = 20,
        locale: Locale? = nil
    ) -> LibrarySearchResults {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return LibrarySearchResults(artifacts: [], destinations: [], interests: [], places: []) }

        let artifactMatches = Array(artifacts.filter {
            searchText(for: $0, locale: locale).localizedCaseInsensitiveContains(term)
        }.prefix(limit))
        let destinations = Array(DestinationOrbitBuilder.nodes(from: artifacts, mode: .automatic, limit: nil)
            .filter { $0.name.localizedCaseInsensitiveContains(term) }
            .prefix(limit))
        let interests = Array(InterestProfileBuilder.build(from: artifacts).interests
            .filter { pattern in
                pattern.name.localizedCaseInsensitiveContains(term) ||
                    InterestDisplayName.localized(pattern.name, locale: locale).localizedCaseInsensitiveContains(term) ||
                    pattern.areaNames.contains { $0.localizedCaseInsensitiveContains(term) }
            }
            .prefix(limit))
        var seen = Set<String>()
        let places = Array(artifacts.compactMap(\.place).filter { place in
            seen.insert(place.id).inserted &&
                (place.name.localizedCaseInsensitiveContains(term) || place.subtitle.localizedCaseInsensitiveContains(term))
        }.prefix(limit))
        return LibrarySearchResults(artifacts: artifactMatches, destinations: destinations, interests: interests, places: places)
    }

    static func title(for artifact: Artifact) -> String {
        if let originalText = firstLine(of: artifact.originalText) { return originalText }
        if let metadataTitle = artifact.linkMetadata?.title { return metadataTitle }
        if let note = firstLine(of: artifact.userNote) { return note }
        if let placeName = artifact.place?.name { return placeName }
        return artifact.kind == .photo
            ? String(localized: "Saved photo")
            : String(localized: "Saved item")
    }

    private static func searchText(for artifact: Artifact, locale: Locale?) -> String {
        var parts = [String]()
        parts.append(title(for: artifact))
        append(artifact.sourceURL, to: &parts)
        append(artifact.userNote, to: &parts)
        append(artifact.extractedText, to: &parts)
        append(artifact.linkMetadata?.summary, to: &parts)
        append(artifact.linkMetadata?.siteName, to: &parts)
        append(artifact.effectiveSummary, to: &parts)
        append(artifact.effectiveCategory?.displayName, to: &parts)
        parts.append(artifact.effectiveInterests.joined(separator: " "))
        parts.append(InterestDisplayName.joined(artifact.effectiveInterests, separator: " ", locale: locale))
        append(artifact.place?.name, to: &parts)
        append(artifact.place?.subtitle, to: &parts)
        return parts.joined(separator: " ")
    }

    private static func append(_ value: String?, to parts: inout [String]) {
        guard let value, !value.isEmpty else { return }
        parts.append(value)
    }

    private static func firstLine(of text: String?) -> String? {
        guard let text else { return nil }
        return text.split(whereSeparator: \.isNewline).first.map(String.init)
    }
}
