//
//  HomeView.swift
//  graviti
//
//  Created by Rhys Gilkenson on 9/17/26.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                GravitiColors.appBackground
                    .ignoresSafeArea()

                // Small brand mark
                VStack {
                    HStack {
                        GravitiWordmark(size: .small)

                        Spacer()
                    }

                    Spacer()
                }
                .padding(.horizontal, 22)
                .padding(.top, 10)

                // Tokyo
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
                .position(
                    x: geometry.size.width * 0.43,
                    y: geometry.size.height * 0.30
                )

                // California
                GravityPlanet(
                    name: "California",
                    level: .stateProvince,
                    saveCount: 18,
                    diameter: 108,
                    primaryColor: GravitiColors.signalMint,
                    highlightColor: Color(
                        red: 126 / 255,
                        green: 244 / 255,
                        blue: 207 / 255
                    )
                )
                .position(
                    x: geometry.size.width * 0.79,
                    y: geometry.size.height * 0.17
                )

                // Montreal
                GravityPlanet(
                    name: "Montreal",
                    level: .city,
                    saveCount: 9,
                    diameter: 90,
                    primaryColor: Color(
                        red: 72 / 255,
                        green: 168 / 255,
                        blue: 240 / 255
                    ),
                    highlightColor: Color(
                        red: 138 / 255,
                        green: 221 / 255,
                        blue: 255 / 255
                    )
                )
                .position(
                    x: geometry.size.width * 0.18,
                    y: geometry.size.height * 0.51
                )

                // Kyoto
                GravityPlanet(
                    name: "Kyoto",
                    level: .city,
                    saveCount: 8,
                    diameter: 94,
                    primaryColor: Color(
                        red: 236 / 255,
                        green: 151 / 255,
                        blue: 58 / 255
                    ),
                    highlightColor: Color(
                        red: 255 / 255,
                        green: 203 / 255,
                        blue: 97 / 255
                    )
                )
                .position(
                    x: geometry.size.width * 0.80,
                    y: geometry.size.height * 0.48
                )

                // Uji
                GravityPlanet(
                    name: "Uji",
                    level: .city,
                    saveCount: 3,
                    diameter: 66,
                    primaryColor: GravitiColors.signalMint,
                    highlightColor: Color(
                        red: 139 / 255,
                        green: 247 / 255,
                        blue: 211 / 255
                    )
                )
                .position(
                    x: geometry.size.width * 0.68,
                    y: geometry.size.height * 0.68
                )
            }
        }
    }
}

#Preview {
    HomeView()
}
