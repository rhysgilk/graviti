import Foundation
import CryptoKit

enum DestinationOrbitBuilder {
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
        let raw = ungroupedNodes(from: artifacts)
        var countries: [String: (name: String, cityIDs: Set<UUID>, placeIDs: Set<String>, count: Int)] = [:]
        for artifact in artifacts {
            guard let place = artifact.place,
                  let country = place.country?.trimmingCharacters(in: .whitespacesAndNewlines), !country.isEmpty else { continue }
            let countryKey = normalized(country)
            var group = countries[countryKey] ?? (country, [], [], 0)
            if let city = place.locality?.trimmingCharacters(in: .whitespacesAndNewlines), !city.isEmpty {
                group.cityIDs.insert(stableID(for: normalized("city|\(country)|\(city)")))
            }
            group.placeIDs.insert(place.id)
            group.count += 1
            countries[countryKey] = group
        }

        let collapsed = countries.values.filter { $0.cityIDs.count >= 2 && $0.count <= 4 }
        let hiddenCityIDs = Set(collapsed.flatMap(\.cityIDs))
        let countryNodes = collapsed.map { group in
            OrbitNode(
                id: stableID(for: normalized("country|\(group.name)|\(group.name)")),
                name: group.name,
                level: .country,
                gravity: score(count: group.count, places: group.placeIDs.count),
                saveCount: group.count
            )
        }
        let countryIDs = Set(countryNodes.map(\.id))
        return sorted(raw.filter { !hiddenCityIDs.contains($0.id) && !countryIDs.contains($0.id) } + countryNodes, limit: limit)
    }

    static func children(of country: OrbitNode, from artifacts: [Artifact], limit: Int? = 10) -> [OrbitNode] {
        guard country.level == .country else { return [] }
        let matching = artifacts.filter {
            guard let name = $0.place?.country else { return false }
            return normalized(name) == normalized(country.name)
        }
        return sorted(ungroupedNodes(from: matching).filter { $0.level == .city }, limit: limit)
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
        let ordered = nodes.sorted {
            if $0.gravity != $1.gravity { return $0.gravity > $1.gravity }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
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
