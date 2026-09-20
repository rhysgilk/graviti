//
//  OrbitNode.swift
//  graviti
//
//  Created by Rhys Gilkenson on 9/17/26.
//

import Foundation

struct OrbitNode: Identifiable, Hashable {
    let id: UUID
    let name: String
    let level: GeoLevel
    let gravity: Double
    let saveCount: Int

    init(
        id: UUID = UUID(),
        name: String,
        level: GeoLevel,
        gravity: Double,
        saveCount: Int
    ) {
        self.id = id
        self.name = name
        self.level = level
        self.gravity = gravity
        self.saveCount = saveCount
    }

    nonisolated static func ranksBefore(_ lhs: OrbitNode, _ rhs: OrbitNode) -> Bool {
        if lhs.gravity != rhs.gravity { return lhs.gravity > rhs.gravity }
        if lhs.saveCount != rhs.saveCount { return lhs.saveCount > rhs.saveCount }
        let nameOrder = lhs.name.localizedStandardCompare(rhs.name)
        if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

enum GeoLevel: String, Hashable {
    case country
    case stateProvince
    case city
    case district
    case neighborhood

    var displayName: String {
        switch self {
        case .country:
            String(localized: "Country")
        case .stateProvince:
            String(localized: "State")
        case .city:
            String(localized: "City")
        case .district:
            String(localized: "District")
        case .neighborhood:
            String(localized: "Neighborhood")
        }
    }
}
