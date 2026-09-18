//
//  HomeView.swift
//  graviti
//
//  Created by Rhys Gilkenson on 9/17/26.
//

import SwiftUI

struct HomeView: View {
    private let orbitItems: [OrbitItem] = [
        OrbitItem(
            node: OrbitNode(
                name: "Tokyo",
                level: .city,
                gravity: 86,
                saveCount: 14
            ),
            x: 0.43,
            y: 0.30,
            primaryColor: GravitiColors.iris,
            highlightColor: Color(
                red: 170 / 255,
                green: 151 / 255,
                blue: 255 / 255
            ),
            driftX: 7,
            driftY: -5,
            driftDurationX: 9,
            driftDurationY: 11
        ),

        OrbitItem(
            node: OrbitNode(
                name: "California",
                level: .stateProvince,
                gravity: 72,
                saveCount: 18
            ),
            x: 0.79,
            y: 0.17,
            primaryColor: GravitiColors.signalMint,
            highlightColor: Color(
                red: 126 / 255,
                green: 244 / 255,
                blue: 207 / 255
            ),
            driftX: -5,
            driftY: 6,
            driftDurationX: 10,
            driftDurationY: 8
        ),

        OrbitItem(
            node: OrbitNode(
                name: "Montreal",
                level: .city,
                gravity: 44,
                saveCount: 9
            ),
            x: 0.18,
            y: 0.51,
            primaryColor: Color(
                red: 72 / 255,
                green: 168 / 255,
                blue: 240 / 255
            ),
            highlightColor: Color(
                red: 138 / 255,
                green: 221 / 255,
                blue: 255 / 255
            ),
            driftX: 6,
            driftY: 4,
            driftDurationX: 8,
            driftDurationY: 10
        ),

        OrbitItem(
            node: OrbitNode(
                name: "Kyoto",
                level: .city,
                gravity: 37,
                saveCount: 8
            ),
            x: 0.80,
            y: 0.48,
            primaryColor: Color(
                red: 236 / 255,
                green: 151 / 255,
                blue: 58 / 255
            ),
            highlightColor: Color(
                red: 255 / 255,
                green: 203 / 255,
                blue: 97 / 255
            ),
            driftX: -6,
            driftY: -5,
            driftDurationX: 11,
            driftDurationY: 9
        ),

        OrbitItem(
            node: OrbitNode(
                name: "Uji",
                level: .city,
                gravity: 18,
                saveCount: 3
            ),
            x: 0.68,
            y: 0.68,
            primaryColor: GravitiColors.signalMint,
            highlightColor: Color(
                red: 139 / 255,
                green: 247 / 255,
                blue: 211 / 255
            ),
            driftX: 4,
            driftY: 6,
            driftDurationX: 7,
            driftDurationY: 10
        )
    ]

    var body: some View {
        GeometryReader { geometry in
            let gravities = orbitItems.map(\.node.gravity)
            let minimumGravity = gravities.min() ?? 0
            let maximumGravity = gravities.max() ?? 1

            ZStack {
                GravitiColors.appBackground
                    .ignoresSafeArea()

                wordmark

                ForEach(orbitItems) { item in
                    GravityPlanet(
                        name: item.node.name,
                        level: item.node.level,
                        saveCount: item.node.saveCount,
                        diameter: GravityScale.diameter(
                            for: item.node.gravity,
                            minimumGravity: minimumGravity,
                            maximumGravity: maximumGravity
                        ),
                        primaryColor: item.primaryColor,
                        highlightColor: item.highlightColor
                    )
                    .position(
                        x: geometry.size.width * item.x,
                        y: geometry.size.height * item.y
                    )
                    .orbitDrift(
                        x: item.driftX,
                        y: item.driftY,
                        xDuration: item.driftDurationX,
                        yDuration: item.driftDurationY
                    )
                }
            }
        }
    }

    private var wordmark: some View {
        VStack {
            HStack {
                GravitiWordmark(size: .small)

                Spacer()
            }

            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
    }
}

private struct OrbitItem: Identifiable {
    let node: OrbitNode

    let x: CGFloat
    let y: CGFloat

    let primaryColor: Color
    let highlightColor: Color

    let driftX: CGFloat
    let driftY: CGFloat

    let driftDurationX: Double
    let driftDurationY: Double

    var id: UUID {
        node.id
    }
}

#Preview {
    HomeView()
}
