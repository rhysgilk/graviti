//
//  GravityScale.swift
//  graviti
//
//  Created by Rhys Gilkenson on 9/17/26.
//

import SwiftUI

enum GravityScale {
    static let minimumDiameter: CGFloat = 66
    static let maximumDiameter: CGFloat = 154

    static func diameter(
        for gravity: Double,
        minimumGravity: Double,
        maximumGravity: Double
    ) -> CGFloat {
        guard maximumGravity > minimumGravity else {
            return (minimumDiameter + maximumDiameter) / 2
        }

        let normalized = (
            gravity - minimumGravity
        ) / (
            maximumGravity - minimumGravity
        )

        let clamped = min(max(normalized, 0), 1)

        // Nonlinear scaling prevents the strongest destination
        // from visually overwhelming everything else.
        let visualWeight = sqrt(clamped)

        return minimumDiameter
            + visualWeight
            * (maximumDiameter - minimumDiameter)
    }
}
