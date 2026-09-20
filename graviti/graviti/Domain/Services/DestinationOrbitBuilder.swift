import Foundation
import CryptoKit

enum DestinationOrbitBuilder {
    private struct CountryRepresentation {
        let collapsed: OrbitNode
        let children: [OrbitNode]

        var expansionPriority: Double {
            let meaningfulSaves = children.filter { $0.saveCount >= 2 }.reduce(0) { $0 + $1.saveCount }
            let coverage = Double(meaningfulSaves) / Double(max(collapsed.saveCount, 1))
            return collapsed.gravity * (0.5 + coverage)
        }

        var shouldExpand: Bool {
            let meaningfulChildren = children.filter { $0.saveCount >= 2 }
            let meaningfulSaves = meaningfulChildren.reduce(0) { $0 + $1.saveCount }
            let coverage = Double(meaningfulSaves) / Double(max(collapsed.saveCount, 1))
            return collapsed.saveCount >= 6 && meaningfulChildren.count >= 2 && coverage >= 0.65
        }
    }

    static func nodes(
        from artifacts: [Artifact],
        mode: OrbitResolutionMode = .automatic,
        limit: Int? = 10
    ) -> [OrbitNode] {
        switch mode {
        case .automatic:
            automaticNodes(from: artifacts, limit: limit)
        case .countries:
            sorted(groupedNodes(from: artifacts, level: .country), limit: limit)
        case .statesProvinces:
            sorted(groupedNodes(from: artifacts, level: .stateProvince), limit: limit)
        case .cities:
            sorted(groupedNodes(from: artifacts, level: .city), limit: limit)
        }
    }

    private static func automaticNodes(from artifacts: [Artifact], limit: Int?) -> [OrbitNode] {
        var countryArtifacts: [String: (name: String, artifacts: [Artifact])] = [:]
        var artifactsWithoutCountry: [Artifact] = []
        for artifact in artifacts {
            guard let place = artifact.place else { continue }
            guard let country = cleaned(place.country) else {
                artifactsWithoutCountry.append(artifact)
                continue
            }
            let countryKey = normalized(country)
            var group = countryArtifacts[countryKey] ?? (country, [])
            group.artifacts.append(artifact)
            countryArtifacts[countryKey] = group
        }

        var nodes = ungroupedNodes(from: artifactsWithoutCountry)
        var expandable: [CountryRepresentation] = []
        for group in countryArtifacts.values {
            let collapsed = node(name: group.name, level: .country, country: group.name, artifacts: group.artifacts)
            let children = adaptiveChildren(from: group.artifacts, country: group.name)
            if children.count <= 1 {
                nodes.append(contentsOf: children.isEmpty ? [collapsed] : children)
            } else {
                nodes.append(collapsed)
                expandable.append(CountryRepresentation(collapsed: collapsed, children: children))
            }
        }

        let labelBudget = limit ?? Int.max
        for representation in expandable.sorted(by: { $0.expansionPriority > $1.expansionPriority }) {
            let addedLabels = representation.children.count - 1
            guard representation.shouldExpand, nodes.count + addedLabels <= labelBudget else { continue }
            nodes.removeAll { $0.id == representation.collapsed.id }
            nodes.append(contentsOf: representation.children)
        }
        return sorted(nodes, limit: limit)
    }

    static func children(of country: OrbitNode, from artifacts: [Artifact], limit: Int? = 10) -> [OrbitNode] {
        guard country.level == .country else { return [] }
        let matching = artifacts.filter {
            guard let name = $0.place?.country else { return false }
            return normalized(name) == normalized(country.name)
        }
        return sorted(adaptiveChildren(from: matching, country: country.name), limit: limit)
    }

    private static func adaptiveChildren(from artifacts: [Artifact], country: String) -> [OrbitNode] {
        var regionArtifacts: [String: (name: String, artifacts: [Artifact])] = [:]
        var withoutRegion: [Artifact] = []
        for artifact in artifacts {
            guard let place = artifact.place else { continue }
            guard let region = cleaned(place.region) else {
                withoutRegion.append(artifact)
                continue
            }
            let key = normalized(region)
            var group = regionArtifacts[key] ?? (region, [])
            group.artifacts.append(artifact)
            regionArtifacts[key] = group
        }

        var nodes = ungroupedNodes(from: withoutRegion)
        for group in regionArtifacts.values {
            let cities = Set(group.artifacts.compactMap { artifact -> String? in
                guard let city = cleaned(artifact.place?.locality) else { return nil }
                return normalized(city)
            })
            if cities.count >= 2 && group.artifacts.count >= 3 {
                nodes.append(node(name: group.name, level: .stateProvince, country: country, artifacts: group.artifacts))
            } else {
                let cityNodes = ungroupedNodes(from: group.artifacts)
                nodes.append(contentsOf: cityNodes.isEmpty
                    ? [node(name: group.name, level: .stateProvince, country: country, artifacts: group.artifacts)]
                    : cityNodes)
            }
        }
        return sorted(nodes, limit: nil)
    }

    private static func node(
        name: String,
        level: GeoLevel,
        country: String,
        artifacts: [Artifact]
    ) -> OrbitNode {
        let placeIDs = Set(artifacts.compactMap(\.place?.id))
        let key = normalized("\(level.rawValue)|\(country)|\(name)")
        return OrbitNode(
            id: stableID(for: key),
            name: name,
            level: level,
            gravity: score(count: artifacts.count, places: placeIDs.count),
            saveCount: artifacts.count
        )
    }

    static func artifacts(for node: OrbitNode, from artifacts: [Artifact]) -> [Artifact] {
        artifacts.filter { artifact in
            guard let place = artifact.place else { return false }
            let country = place.country?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let region = place.region?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let city = place.locality?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            switch node.level {
            case .country:
                return stableID(for: normalized("country|\(country)|\(country)")) == node.id
            case .city:
                return stableID(for: normalized("city|\(country)|\(city)")) == node.id
            case .stateProvince:
                return stableID(for: normalized("stateProvince|\(country)|\(region)")) == node.id
            case .district, .neighborhood:
                return false
            }
        }
    }

    private static func groupedNodes(from artifacts: [Artifact], level requestedLevel: GeoLevel) -> [OrbitNode] {
        struct Group {
            let name: String
            let level: GeoLevel
            var artifactCount: Int
            var placeIDs: Set<String>
        }

        var groups: [String: Group] = [:]
        for artifact in artifacts {
            guard let place = artifact.place else { continue }
            let country = cleaned(place.country)
            let region = cleaned(place.region)
            let city = cleaned(place.locality)

            let value: String?
            let level: GeoLevel
            switch requestedLevel {
            case .country:
                value = country
                level = .country
            case .stateProvince:
                value = region ?? country
                level = region == nil ? .country : .stateProvince
            case .city:
                value = city ?? region ?? country
                level = city != nil ? .city : (region != nil ? .stateProvince : .country)
            case .district, .neighborhood:
                value = city ?? region ?? country
                level = city != nil ? .city : (region != nil ? .stateProvince : .country)
            }
            guard let value else { continue }
            let key = normalized("\(level.rawValue)|\(country ?? "")|\(value)")
            var group = groups[key] ?? Group(name: value, level: level, artifactCount: 0, placeIDs: [])
            group.artifactCount += 1
            group.placeIDs.insert(place.id)
            groups[key] = group
        }

        return groups.map { key, group in
            OrbitNode(
                id: stableID(for: key),
                name: group.name,
                level: group.level,
                gravity: score(count: group.artifactCount, places: group.placeIDs.count),
                saveCount: group.artifactCount
            )
        }
    }

    private static func ungroupedNodes(from artifacts: [Artifact]) -> [OrbitNode] {
        struct Group {
            let name: String
            let level: GeoLevel
            var artifactCount: Int
            var placeIDs: Set<String>
        }

        var groups: [String: Group] = [:]
        for artifact in artifacts {
            guard let place = artifact.place else { continue }
            let city = place.locality?.trimmingCharacters(in: .whitespacesAndNewlines)
            let country = place.country?.trimmingCharacters(in: .whitespacesAndNewlines)
            let name: String
            let level: GeoLevel
            if let city, !city.isEmpty {
                name = city
                level = .city
            } else if let country, !country.isEmpty {
                name = country
                level = .country
            } else {
                continue
            }
            let key = normalized("\(level.rawValue)|\(country ?? "")|\(name)")
            var group = groups[key] ?? Group(name: name, level: level, artifactCount: 0, placeIDs: [])
            group.artifactCount += 1
            group.placeIDs.insert(place.id)
            groups[key] = group
        }

        return groups.map { key, group in
            OrbitNode(
                id: stableID(for: key),
                name: group.name,
                level: group.level,
                gravity: score(count: group.artifactCount, places: group.placeIDs.count),
                saveCount: group.artifactCount
            )
        }
    }

    private static func score(count: Int, places: Int) -> Double {
        min(100, Double(22 + count * 11 + max(0, places - 1) * 5))
    }

    private static func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func cleaned(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }

    private static func sorted(_ nodes: [OrbitNode], limit: Int?) -> [OrbitNode] {
        let ordered = nodes.sorted(by: OrbitNode.ranksBefore)
        return limit.map { Array(ordered.prefix($0)) } ?? ordered
    }

    private static func stableID(for key: String) -> UUID {
        let bytes = Array(SHA256.hash(data: Data(key.utf8)))
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
