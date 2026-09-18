//
//  HomeView.swift
//  graviti
//
//  Created by Rhys Gilkenson on 9/17/26.
//

import SwiftUI

struct HomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var presentation: HomePresentation = .field
    @State private var fieldPath: [OrbitItem] = []
    @AccessibilityFocusState private var isDetailFocused: Bool
    @AccessibilityFocusState private var isInsightFocused: Bool

    private static let orbitItems: [OrbitItem] = [
        OrbitItem(
            node: OrbitNode(
                name: "Tokyo",
                level: .city,
                gravity: 86,
                saveCount: 14
            ),
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

    private static let homeInsight = HomeInsight(nodes: orbitItems.map(\.node))

    var body: some View {
        GeometryReader { geometry in
            let items = currentItems
            let layout = OrbitLayoutEngine.layout(items: items, in: geometry.size)

            ZStack {
                GravitiColors.appBackground
                    .ignoresSafeArea()
                    .onTapGesture {
                        if presentation != .field { clearPresentation() }
                    }

                header

                ForEach(items) { item in
                    let isSelected = selectedNodeID == item.id
                    let isInsightLeader = presentation == .insight && item.id == Self.homeInsight?.leadingDestination.id
                    let isFocusedPlanet = isSelected || isInsightLeader
                    let diameter = layout.diameter(for: item)

                    Button {
                        select(item)
                    } label: {
                        planet(for: item, diameter: diameter)
                            .opacity(reduceMotion && isFocusedPlanet ? 0 : (presentation == .field || isFocusedPlanet ? 1 : 0.24))
                    }
                    .buttonStyle(.plain)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Circle())
                    .scaleEffect(isFocusedPlanet ? (reduceMotion ? 1 : 1.12) : (presentation == .field ? 1 : 0.90))
                    .position(
                        isFocusedPlanet && !reduceMotion
                            ? layout.focusPoint
                            : layout.position(for: item)
                    )
                    .orbitDrift(
                        x: item.driftX,
                        y: item.driftY,
                        xDuration: item.driftDurationX,
                        yDuration: item.driftDurationY,
                        isActive: presentation == .field && layout.allowsDrift
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
                    .zIndex(isFocusedPlanet ? 1 : 0)
                    .accessibilityLabel("\(item.node.name), \(item.node.level.displayName), Gravity \(Int(item.node.gravity)), \(item.node.saveCount) saved items")
                    .accessibilityHint(isSelected ? "Closes destination" : "Opens destination")
                    .accessibilityValue(isSelected ? "Selected" : (isInsightLeader ? "Leading destination" : ""))
                    .accessibilitySortPriority(item.node.gravity)
                    .accessibilityHidden(reduceMotion && isFocusedPlanet)
                }

                if reduceMotion, let focusedItem {
                    planet(
                        for: focusedItem,
                        diameter: layout.diameter(for: focusedItem)
                    )
                    .scaleEffect(1.08)
                    .position(layout.focusPoint)
                    .transition(.opacity)
                    .accessibilityHidden(true)
                }

            }
            .overlay(alignment: .bottom) {
                presentedCard
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
            .animation(reduceMotion ? .easeOut(duration: 0.2) : .easeInOut(duration: 0.55), value: presentation)
            .animation(.easeInOut(duration: reduceMotion ? 0.2 : 0.4), value: fieldPath.map(\.id))
        }
        .onChange(of: presentation) { _, newValue in
            isDetailFocused = selectedNodeID != nil
            isInsightFocused = newValue == .insight
        }
    }

    private var selectedNodeID: UUID? {
        if case let .destination(id) = presentation { return id }
        return nil
    }

    private var selectedItem: OrbitItem? {
        currentItems.first { $0.id == selectedNodeID }
    }

    private var insightLeaderItem: OrbitItem? {
        guard fieldPath.isEmpty, let leaderID = Self.homeInsight?.leadingDestination.id else {
            return nil
        }
        return Self.orbitItems.first { $0.id == leaderID }
    }

    private var focusedItem: OrbitItem? {
        selectedItem ?? (presentation == .insight ? insightLeaderItem : nil)
    }

    @ViewBuilder
    private var presentedCard: some View {
        if let selectedItem {
            DestinationSelectionCard(
                node: selectedItem.node,
                onClose: clearPresentation,
                onOpen: SampleOrbitChildren.children(for: selectedItem).isEmpty
                    ? nil
                    : { open(selectedItem) }
            )
            .accessibilityElement(children: .contain)
            .accessibilityFocused($isDetailFocused)
            .transition(cardTransition)
        } else if presentation == .insight, let insight = Self.homeInsight,
                  let leader = insightLeaderItem {
            HomeInsightCard(
                insight: insight,
                onClose: clearPresentation,
                onViewDestination: { select(leader) }
            )
            .accessibilityElement(children: .contain)
            .accessibilityFocused($isInsightFocused)
            .transition(cardTransition)
        }
    }

    private var cardTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 12))
    }

    private var currentItems: [OrbitItem] {
        guard let parent = fieldPath.last else { return Self.orbitItems }
        return SampleOrbitChildren.children(for: parent)
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
        presentation = selectedNodeID == item.id ? .field : .destination(item.id)
    }

    private func clearPresentation() {
        presentation = .field
    }

    private func showInsight() {
        guard fieldPath.isEmpty, Self.homeInsight != nil else { return }
        presentation = presentation == .insight ? .field : .insight
    }

    private func open(_ item: OrbitItem) {
        fieldPath.append(item)
        presentation = .field
    }

    private func goBack() {
        presentation = fieldPath.popLast().map { .destination($0.id) } ?? .field
    }

    private var header: some View {
        VStack {
            HStack {
                if let parent = fieldPath.last {
                    Button(action: goBack) {
                        Label("Back", systemImage: "chevron.backward")
                            .labelStyle(.iconOnly)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Back to Gravity Field")

                    Text(parent.node.name)
                        .font(.custom("Sora-SemiBold", size: 18, relativeTo: .headline))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .accessibilityAddTraits(.isHeader)

                    Spacer()
                } else {
                    GravitiWordmark(size: .small)

                    Spacer()

                    if Self.homeInsight != nil {
                        Button(action: showInsight) {
                            Label("Insight", systemImage: "chart.bar.xaxis")
                                .font(.subheadline.weight(.medium))
                                .frame(minHeight: 44)
                                .padding(.horizontal, 12)
                                .background(.white.opacity(0.08), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(presentation == .insight ? "Close field insight" : "Open field insight")
                        .accessibilityValue(presentation == .insight ? "Selected" : "")
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
    }
}

private enum HomePresentation: Equatable {
    case field
    case destination(UUID)
    case insight
}

#Preview {
    HomeView()
}
