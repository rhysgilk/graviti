import Foundation

struct HomeInsight: Identifiable {
    enum Kind: String {
        case gainingGravity
        case geographicSplit
        case recurringInterest
        case quietDestination
        case fieldLeader
    }

    let id: String
    let kind: Kind
    let destination: OrbitNode
    let eyebrow: String
    let title: String
    let detail: String
}

enum HomeInsightBuilder {
    private struct DestinationEvidence {
        let node: OrbitNode
        let artifacts: [Artifact]

        var country: String? {
            artifacts.compactMap(\.place?.country).first(where: { !$0.isEmpty })
        }
    }

    static func build(
        nodes: [OrbitNode],
        artifacts: [Artifact],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [HomeInsight] {
        let orderedNodes = nodes.sorted(by: OrbitNode.ranksBefore)
        guard let leader = orderedNodes.first else { return [] }

        let evidence = orderedNodes.map {
            DestinationEvidence(
                node: $0,
                artifacts: DestinationOrbitBuilder.artifacts(for: $0, from: artifacts)
            )
        }
        var insights: [HomeInsight] = []

        if let gaining = gainingInsight(from: evidence, now: now, calendar: calendar) {
            insights.append(gaining)
        }
        if let split = splitInsight(from: evidence) {
            insights.append(split)
        }
        if let recurring = recurringInterestInsight(from: evidence) {
            insights.append(recurring)
        }
        if let quiet = quietInsight(from: evidence, now: now, calendar: calendar) {
            insights.append(quiet)
        }

        if insights.isEmpty {
            insights.append(HomeInsight(
                id: "leader|\(leader.id)",
                kind: .fieldLeader,
                destination: leader,
                eyebrow: GravitiCopy.destinationCount(orderedNodes.count),
                title: String(localized: "\(leader.name) leads your field"),
                detail: "\(Int(leader.gravity)) Gravity · \(GravitiCopy.savedItems(leader.saveCount))"
            ))
        }
        return Array(insights.prefix(4))
    }

    private static func gainingInsight(
        from evidence: [DestinationEvidence],
        now: Date,
        calendar: Calendar
    ) -> HomeInsight? {
        guard let recentCutoff = calendar.date(byAdding: .day, value: -30, to: now),
              let priorCutoff = calendar.date(byAdding: .day, value: -60, to: now) else {
            return nil
        }

        let candidates = evidence.compactMap { item -> (DestinationEvidence, Int, Int, Int)? in
            let recent = item.artifacts.filter { $0.capturedAt >= recentCutoff && $0.capturedAt <= now }
            let prior = item.artifacts.filter { $0.capturedAt >= priorCutoff && $0.capturedAt < recentCutoff }
            let recentPlaces = Set(recent.compactMap(\.place?.id)).count
            guard recent.count >= 3, recentPlaces >= 2, recent.count >= prior.count + 2 else { return nil }
            return (item, recent.count, prior.count, recentPlaces)
        }
        .sorted {
            if $0.1 != $1.1 { return $0.1 > $1.1 }
            if $0.3 != $1.3 { return $0.3 > $1.3 }
            return OrbitNode.ranksBefore($0.0.node, $1.0.node)
        }
        guard let candidate = candidates.first else { return nil }

        return HomeInsight(
            id: "gaining|\(candidate.0.node.id)|\(candidate.1)",
            kind: .gainingGravity,
            destination: candidate.0.node,
            eyebrow: String(localized: "Growing now"),
            title: String(localized: "\(candidate.0.node.name) is gaining Gravity"),
            detail: GravitiCopy.recentSaves(candidate.1, placeCount: candidate.3, dayCount: 30)
        )
    }

    private static func splitInsight(from evidence: [DestinationEvidence]) -> HomeInsight? {
        let grouped = Dictionary(grouping: evidence.filter { $0.node.level != .country }) {
            normalized($0.country ?? "")
        }
        let candidates = grouped.compactMap { key, members -> (String, [DestinationEvidence])? in
            guard !key.isEmpty,
                  let country = members.compactMap(\.country).first,
                  members.count >= 2,
                  members.filter({ $0.node.saveCount >= 2 }).count >= 2,
                  members.reduce(0, { $0 + $1.node.saveCount }) >= 6 else {
                return nil
            }
            return (country, members.sorted { OrbitNode.ranksBefore($0.node, $1.node) })
        }
        .sorted {
            let lhsTotal = $0.1.reduce(0) { $0 + $1.node.saveCount }
            let rhsTotal = $1.1.reduce(0) { $0 + $1.node.saveCount }
            if lhsTotal != rhsTotal { return lhsTotal > rhsTotal }
            return $0.0.localizedStandardCompare($1.0) == .orderedAscending
        }
        guard let candidate = candidates.first, let focus = candidate.1.first else { return nil }
        let names = candidate.1.prefix(3).map(\.node.name)

        return HomeInsight(
            id: "split|\(normalized(candidate.0))|\(names.joined(separator: "|"))",
            kind: .geographicSplit,
            destination: focus.node,
            eyebrow: String(localized: "Taking shape"),
            title: String(localized: "\(candidate.0) is coming into focus"),
            detail: GravitiCopy.geographicSplit(names)
        )
    }

    private static func recurringInterestInsight(from evidence: [DestinationEvidence]) -> HomeInsight? {
        struct InterestEvidence {
            var artifactsByID: [UUID: Artifact] = [:]
            var destinationCounts: [UUID: Int] = [:]
        }
        var grouped: [String: InterestEvidence] = [:]
        var displayNames: [String: String] = [:]

        for item in evidence {
            for artifact in item.artifacts {
                for interest in Set(artifact.effectiveInterests) {
                    let key = normalized(interest)
                    guard !key.isEmpty else { continue }
                    displayNames[key] = displayNames[key] ?? interest
                    grouped[key, default: InterestEvidence()].artifactsByID[artifact.id] = artifact
                    grouped[key, default: InterestEvidence()].destinationCounts[item.node.id, default: 0] += 1
                }
            }
        }

        let candidates = grouped.compactMap { key, interest -> (String, InterestEvidence)? in
            let total = interest.artifactsByID.count
            let areaCount = interest.destinationCounts.count
            let largestArea = interest.destinationCounts.values.max() ?? 0
            guard total >= 3, areaCount >= 2, Double(largestArea) / Double(total) <= 0.75,
                  let displayName = displayNames[key] else { return nil }
            return (displayName, interest)
        }
        .sorted {
            if $0.1.destinationCounts.count != $1.1.destinationCounts.count {
                return $0.1.destinationCounts.count > $1.1.destinationCounts.count
            }
            if $0.1.artifactsByID.count != $1.1.artifactsByID.count {
                return $0.1.artifactsByID.count > $1.1.artifactsByID.count
            }
            return $0.0.localizedStandardCompare($1.0) == .orderedAscending
        }
        guard let candidate = candidates.first,
              let focusID = candidate.1.destinationCounts.sorted(by: {
                  if $0.value != $1.value { return $0.value > $1.value }
                  return $0.key.uuidString < $1.key.uuidString
              }).first?.key,
              let focus = evidence.first(where: { $0.node.id == focusID }) else {
            return nil
        }

        return HomeInsight(
            id: "interest|\(normalized(candidate.0))|\(focusID)",
            kind: .recurringInterest,
            destination: focus.node,
            eyebrow: String(localized: "Across your Library"),
            title: String(localized: "\(candidate.0) keeps showing up"),
            detail: GravitiCopy.savesAcrossDestinations(
                candidate.1.artifactsByID.count,
                destinationCount: candidate.1.destinationCounts.count
            )
        )
    }

    private static func quietInsight(
        from evidence: [DestinationEvidence],
        now: Date,
        calendar: Calendar
    ) -> HomeInsight? {
        guard let quietCutoff = calendar.date(byAdding: .day, value: -120, to: now) else { return nil }
        let candidates = evidence.compactMap { item -> (DestinationEvidence, Date)? in
            guard item.node.saveCount >= 3,
                  let latest = item.artifacts.map(\.capturedAt).max(),
                  latest < quietCutoff else { return nil }
            return (item, latest)
        }
        .sorted {
            if $0.0.node.gravity != $1.0.node.gravity { return $0.0.node.gravity > $1.0.node.gravity }
            return $0.1 < $1.1
        }
        guard let candidate = candidates.first else { return nil }
        let months = max(4, calendar.dateComponents([.month], from: candidate.1, to: now).month ?? 4)

        return HomeInsight(
            id: "quiet|\(candidate.0.node.id)|\(months)",
            kind: .quietDestination,
            destination: candidate.0.node,
            eyebrow: String(localized: "Quiet lately"),
            title: String(localized: "\(candidate.0.node.name) has gone quiet"),
            detail: GravitiCopy.noNewSaves(monthCount: months)
        )
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }
}
