//
//  HomeView.swift
//  graviti
//
//  Created by Rhys Gilkenson on 9/17/26.
//

import SwiftUI

struct HomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedNodeID: UUID?
    @AccessibilityFocusState private var isDetailFocused: Bool

    private static let orbitItems: [OrbitItem] = [
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
            let gravities = Self.orbitItems.map(\.node.gravity)
            let minimumGravity = gravities.min() ?? 0
            let maximumGravity = gravities.max() ?? 1

            ZStack {
                GravitiColors.appBackground
                    .ignoresSafeArea()

                if selectedNodeID != nil {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture(perform: clearSelection)
                        .accessibilityHidden(true)
                }

                wordmark

                ForEach(Self.orbitItems) { item in
                    let isSelected = selectedNodeID == item.id
                    let diameter = GravityScale.diameter(
                        for: item.node.gravity,
                        minimumGravity: minimumGravity,
                        maximumGravity: maximumGravity
                    )

                    Button {
                        select(item)
                    } label: {
                        planet(for: item, diameter: diameter)
                    }
                    .buttonStyle(.plain)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Circle())
                    .scaleEffect(isSelected ? (reduceMotion ? 1 : 1.12) : (selectedNodeID == nil ? 1 : 0.90))
                    .opacity(reduceMotion && isSelected ? 0 : (selectedNodeID == nil || isSelected ? 1 : 0.24))
                    .position(
                        x: geometry.size.width * (isSelected && !reduceMotion ? 0.5 : item.x),
                        y: geometry.size.height * (isSelected && !reduceMotion ? 0.35 : item.y)
                    )
                    .orbitDrift(
                        x: item.driftX,
                        y: item.driftY,
                        xDuration: item.driftDurationX,
                        yDuration: item.driftDurationY,
                        isActive: selectedNodeID == nil
                    )
                    .zIndex(isSelected ? 1 : 0)
                    .accessibilityLabel("\(item.node.name), \(item.node.level.displayName), Gravity \(Int(item.node.gravity)), \(item.node.saveCount) saved items")
                    .accessibilityHint(isSelected ? "Closes destination" : "Opens destination")
                    .accessibilityValue(isSelected ? "Selected" : "")
                    .accessibilitySortPriority(item.node.gravity)
                    .accessibilityHidden(reduceMotion && isSelected)
                }

                if reduceMotion, let selectedItem {
                    planet(
                        for: selectedItem,
                        diameter: GravityScale.diameter(
                            for: selectedItem.node.gravity,
                            minimumGravity: minimumGravity,
                            maximumGravity: maximumGravity
                        )
                    )
                    .scaleEffect(1.08)
                    .position(
                        x: geometry.size.width * 0.5,
                        y: geometry.size.height * 0.35
                    )
                    .transition(.opacity)
                    .accessibilityHidden(true)
                }

                if let selectedItem {
                    DestinationSelectionCard(node: selectedItem.node, onClose: clearSelection)
                        .accessibilityElement(children: .contain)
                        .accessibilityFocused($isDetailFocused)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 12)))
                        .zIndex(2)
                }
            }
            .animation(reduceMotion ? .easeOut(duration: 0.2) : .easeInOut(duration: 0.55), value: selectedNodeID)
        }
        .onChange(of: selectedNodeID) { _, newValue in
            isDetailFocused = newValue != nil
        }
    }

    private var selectedItem: OrbitItem? {
        Self.orbitItems.first { $0.id == selectedNodeID }
    }

    private func planet(for item: OrbitItem, diameter: CGFloat) -> some View {
        GravityPlanet(
            name: item.node.name,
            level: item.node.level,
            saveCount: item.node.saveCount,
            diameter: diameter,
            primaryColor: item.primaryColor,
            highlightColor: item.highlightColor
        )
    }

    private func select(_ item: OrbitItem) {
        selectedNodeID = selectedNodeID == item.id ? nil : item.id
    }

    private func clearSelection() {
        selectedNodeID = nil
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
