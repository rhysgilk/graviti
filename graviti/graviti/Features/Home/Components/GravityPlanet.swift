//
//  GravityPlanet.swift
//  graviti
//
//  Created by Rhys Gilkenson on 9/17/26.
//

import SwiftUI

struct GravityPlanet: View {
    let name: String
    let level: GeoLevel
    let saveCount: Int
    let diameter: CGFloat
    let primaryColor: Color
    let highlightColor: Color

    var body: some View {
        ZStack {
            // Soft outer radiance
            Circle()
                .fill(primaryColor.opacity(0.18))
                .blur(radius: diameter * 0.10)
                .scaleEffect(1.08)

            // Planet body
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            highlightColor.opacity(0.95),
                            primaryColor.opacity(0.78),
                            primaryColor.opacity(0.48)
                        ],
                        center: UnitPoint(x: 0.35, y: 0.28),
                        startRadius: 0,
                        endRadius: diameter * 0.65
                    )
                )

            // Iridescent edge
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            highlightColor.opacity(0.75),
                            .white.opacity(0.65),
                            primaryColor.opacity(0.75),
                            highlightColor,
                            primaryColor.opacity(0.75)
                        ],
                        center: .center
                    ),
                    lineWidth: 1.4
                )

            VStack(spacing: 4) {
                Text(name)
                    .font(GravitiTypography.display(nameFontSize))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)

                if diameter >= 75 {
                    Text("\(level.displayName.uppercased()) · \(saveCount)")
                        .font(.system(size: metadataFontSize, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .padding(diameter * 0.12)
        }
        .frame(width: diameter, height: diameter)
        .dynamicTypeSize(.large)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(name), \(level.displayName), \(saveCount) saved items"
        )
    }

    private var nameFontSize: CGFloat {
        switch diameter {
        case ..<75:
            return 11
        case ..<105:
            return 13
        case ..<140:
            return 15
        default:
            return 18
        }
    }

    private var metadataFontSize: CGFloat {
        diameter >= 120 ? 9 : 8
    }
}

#Preview {
    ZStack {
        GravitiColors.appBackground
            .ignoresSafeArea()

        GravityPlanet(
            name: "Tokyo",
            level: .city,
            saveCount: 14,
            diameter: 150,
            primaryColor: GravitiColors.iris,
            highlightColor: Color(
                red: 170 / 255,
                green: 151 / 255,
                blue: 255 / 255
            )
        )
    }
}
