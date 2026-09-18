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
            "Country"
        case .stateProvince:
            "State"
        case .city:
            "City"
        case .district:
            "District"
        case .neighborhood:
            "Neighborhood"
        }
    }
}
