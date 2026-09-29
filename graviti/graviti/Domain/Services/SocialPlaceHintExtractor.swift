import Foundation

struct SocialPlaceHint: Equatable {
    let expectedName: String
    let queries: [String]
}

protocol SocialPlaceHintProviding {
    func hint(for artifact: Artifact) -> SocialPlaceHint?
    func namesAreCompatible(_ expected: String, _ candidate: String) -> Bool
}

struct DefaultSocialPlaceHintProvider: SocialPlaceHintProviding {
    func hint(for artifact: Artifact) -> SocialPlaceHint? {
        SocialPlaceHintExtractor.hint(for: artifact)
    }

    func namesAreCompatible(_ expected: String, _ candidate: String) -> Bool {
        SocialPlaceHintExtractor.namesAreCompatible(expected, candidate)
    }
}

enum SocialPlaceHintExtractor {
    static func hint(for artifact: Artifact) -> SocialPlaceHint? {
        guard let rawURL = artifact.sourceURL,
              isInstagramURL(rawURL),
              artifact.linkMetadataState == .processed,
              let caption = artifact.linkMetadata?.summary else { return nil }

        if let pinRange = caption.range(of: "📍") {
            let pinnedText = String(caption[pinRange.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let hint = pinnedHint(in: pinnedText) { return hint }
        }

        // A handle at the very start of a caption is commonly the featured venue.
        // Later handles are often the creator or an account the author asks users to follow.
        if let handle = firstMatch(#"^\s*@([A-Za-z0-9._]{2,30})\b"#, in: caption, group: 1) {
            return handleHint(handle, context: streetAddress(in: caption))
        }

        // Some captions name a venue and street in prose instead of using a map pin.
        // “Growl Growl on Winter Street” is strong enough to search without guessing
        // from a generic city mention elsewhere in the caption.
        if let parts = firstGroups(
            #"\b([A-Z][\p{L}0-9&'’.\-]*(?:\s+[A-Z][\p{L}0-9&'’.\-]*){0,4})\s+on\s+([A-Z][\p{L}0-9'’.\-]*(?:\s+[A-Z][\p{L}0-9'’.\-]*){0,3}\s+(?:Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Drive|Dr|Lane|Ln|Way|Court|Ct|Place|Pl|Parkway|Pkwy))\b"#,
            in: caption,
            groups: [1, 2]
        ), parts.count == 2 {
            let name = parts[0]
            return SocialPlaceHint(expectedName: name, queries: ["\(name), \(parts[1])", name])
        }

        return nil
    }

    private static func pinnedHint(in pinnedText: String) -> SocialPlaceHint? {
        guard !pinnedText.isEmpty else { return nil }

        // Preserve an explicit “Place, City, ST” tuple before looking for handles.
        // This prevents a later “follow @creator” phrase from replacing the venue.
        if let parts = firstGroups(
            #"^\s*([\p{L}0-9&'’.\- ]{2,80}?),\s*([\p{L}.'’\- ]{2,50}?),\s*([A-Za-z]{2})(?=\s|$)"#,
            in: pinnedText,
            groups: [1, 2, 3]
        ), parts.count == 3 {
            let name = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let context = parts.dropFirst().joined(separator: ", ")
            let searchContext = parts.dropFirst().joined(separator: " ")
            return SocialPlaceHint(
                expectedName: name,
                queries: ["\(name) \(searchContext) restaurant", "\(name), \(context)", name]
            )
        }

        if let handle = firstMatch(
            #"^(?:(?!\bfollow\b).){0,100}@([A-Za-z0-9._]{2,30})\b"#,
            in: pinnedText,
            group: 1
        ) {
            return handleHint(handle, context: streetAddress(in: pinnedText))
        }

        let clause = pinnedText.components(separatedBy: CharacterSet(charactersIn: "\n•|"))[0]
        let name = clause
            .components(separatedBy: " — ")[0]
            .components(separatedBy: " - ")[0]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard (3...80).contains(name.count),
              name.rangeOfCharacter(from: .letters) != nil else { return nil }
        return SocialPlaceHint(expectedName: name, queries: [name])
    }

    private static func handleHint(_ handle: String, context: String?) -> SocialPlaceHint {
        let words = handle.replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        let genericSuffixes: Set<String> = ["official", "restaurant", "cafe", "usa", "us"]
        let meaningfulWords = words.dropLast(words.last.map { genericSuffixes.contains($0.lowercased()) } == true ? 1 : 0)
        let name = meaningfulWords.joined(separator: " ")
        return SocialPlaceHint(
            expectedName: name,
            queries: unique([query(name: name, context: context), name])
        )
    }

    static func isSupportedSocialURL(_ rawURL: String) -> Bool {
        isInstagramURL(rawURL)
    }

    static func namesAreCompatible(_ expected: String, _ candidate: String) -> Bool {
        let expectedName = normalized(expected)
        let candidateName = normalized(candidate)
        let compactExpected = expectedName.replacingOccurrences(of: " ", with: "")
        let compactCandidate = candidateName.replacingOccurrences(of: " ", with: "")
        guard !compactExpected.isEmpty, !compactCandidate.isEmpty else { return false }
        if compactExpected == compactCandidate { return true }
        if compactExpected.contains(compactCandidate) || compactCandidate.contains(compactExpected) {
            return Double(min(compactExpected.count, compactCandidate.count)) /
                Double(max(compactExpected.count, compactCandidate.count)) >= 0.7
        }
        let expectedTokens = Set(expectedName.split(separator: " ").map(String.init).filter { $0.count > 1 })
        let candidateTokens = Set(candidateName.split(separator: " ").map(String.init).filter { $0.count > 1 })
        guard !expectedTokens.isEmpty, !candidateTokens.isEmpty else { return false }
        let overlap = expectedTokens.intersection(candidateTokens).count
        return Double(overlap) / Double(max(expectedTokens.count, candidateTokens.count)) >= 0.75
    }

    private static func streetAddress(in text: String) -> String? {
        // Capture a conventional numbered street address plus its city/region tail.
        // The end is deliberately bounded so hashtags or the rest of a caption are excluded.
        firstMatch(
            #"\b(\d{1,6}\s+[\p{L}0-9.'’\- ]{2,60}\s(?:St(?:reet)?|Ave(?:nue)?|Rd|Road|Blvd|Boulevard|Dr(?:ive)?|Ln|Lane|Way|Ct|Court|Pl(?:ace)?|Pkwy|Parkway)\b(?:[, ]+[\p{L}.'’\- ]{2,40})?(?:,?\s*[A-Z]{2})?(?:\s+\d{5}(?:-\d{4})?)?)"#,
            in: text,
            group: 1
        )?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func query(name: String, context: String?) -> String {
        guard let context, !context.isEmpty else { return name }
        return "\(name), \(context)"
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0.lowercased()).inserted }
    }

    private static func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .joined(separator: " ")
    }

    private static func firstMatch(_ pattern: String, in text: String, group: Int) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.range(at: group).location != NSNotFound,
              let range = Range(match.range(at: group), in: text) else { return nil }
        return String(text[range])
    }

    private static func firstGroups(_ pattern: String, in text: String, groups: [Int]) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        let values = groups.compactMap { group -> String? in
            guard match.range(at: group).location != NSNotFound,
                  let range = Range(match.range(at: group), in: text) else { return nil }
            return String(text[range])
        }
        return values.count == groups.count ? values : nil
    }

    private static func isInstagramURL(_ rawURL: String) -> Bool {
        guard let host = URLComponents(string: rawURL)?.host?.lowercased() else { return false }
        return host == "instagram.com" || host.hasSuffix(".instagram.com")
    }
}
