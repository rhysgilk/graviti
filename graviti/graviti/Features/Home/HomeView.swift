//
//  HomeView.swift
//  graviti
//
//  Created by Rhys Gilkenson on 9/17/26.
//

import SwiftUI

struct HomeView: View {
    @ObservedObject var library: ArtifactLibrary
    let onSave: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var presentation: HomePresentation = .field
    @State private var fieldPath: [OrbitItem] = []
    @State private var presentedDestination: OrbitNode?
    @AppStorage("orbit.resolutionMode") private var resolutionModeRawValue = OrbitResolutionMode.automatic.rawValue
    @AccessibilityFocusState private var isDetailFocused: Bool
    @AccessibilityFocusState private var isInsightFocused: Bool

    private var orbitItems: [OrbitItem] {
        items(for: DestinationOrbitBuilder.nodes(from: library.artifacts, mode: resolutionMode))
    }

    private var resolutionMode: OrbitResolutionMode {
        get { OrbitResolutionMode(rawValue: resolutionModeRawValue) ?? .automatic }
        nonmutating set { resolutionModeRawValue = newValue.rawValue }
    }

    private func items(for nodes: [OrbitNode]) -> [OrbitItem] {
        let colors: [(Color, Color)] = [
            (GravitiColors.iris, Color(red: 170 / 255, green: 151 / 255, blue: 255 / 255)),
            (GravitiColors.signalMint, Color(red: 126 / 255, green: 244 / 255, blue: 207 / 255)),
            (Color(red: 72 / 255, green: 168 / 255, blue: 240 / 255), Color(red: 138 / 255, green: 221 / 255, blue: 255 / 255)),
            (Color(red: 236 / 255, green: 151 / 255, blue: 58 / 255), Color(red: 255 / 255, green: 203 / 255, blue: 97 / 255))
        ]
        return nodes.enumerated().map { index, node in
            let color = colors[index % colors.count]
            return OrbitItem(
                node: node,
                primaryColor: color.0,
                highlightColor: color.1,
                driftX: index.isMultiple(of: 2) ? 5 : -5,
                driftY: index.isMultiple(of: 3) ? -4 : 5,
                driftDurationX: Double(8 + index % 4),
                driftDurationY: Double(9 + index % 3)
            )
        }
    }

    private var homeInsight: HomeInsight? {
        HomeInsight(nodes: orbitItems.map(\.node))
    }

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

                if items.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "circle.grid.cross")
                            .font(.system(size: 38))
                            .foregroundStyle(GravitiColors.signalMint)
                        Text("Your field starts here")
                            .font(.custom("Sora-SemiBold", size: 23, relativeTo: .title2))
                        Text("Save a place to see where your interests are pulling you.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.7))
                        Button("Find a place", action: onSave)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(minWidth: 180, minHeight: 48)
                            .background(GravitiColors.iris, in: Capsule())
                            .buttonStyle(.plain)
                    }
                    .padding(28)
                }

                ForEach(items) { item in
                    let isSelected = selectedNodeID == item.id
                    let isInsightLeader = presentation == .insight && item.id == homeInsight?.leadingDestination.id
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
                    .accessibilityLabel("\(item.node.name), \(item.node.level.displayName), Gravity \(Int(item.node.gravity)), \(GravitiCopy.savedItems(item.node.saveCount))")
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
            .animation(.easeInOut(duration: reduceMotion ? 0.2 : 0.4), value: items.map(\.id))
        }
        .onChange(of: presentation) { _, newValue in
            isDetailFocused = selectedNodeID != nil
            isInsightFocused = newValue == .insight
        }
        .onChange(of: resolutionModeRawValue) { _, _ in
            fieldPath.removeAll()
            clearPresentation()
        }
        .sheet(item: $presentedDestination) { node in
            NavigationStack {
                DestinationLibraryDetailView(node: node, library: library)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { presentedDestination = nil }
                        }
                    }
            }
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
        guard fieldPath.isEmpty, let leaderID = homeInsight?.leadingDestination.id else {
            return nil
        }
        return orbitItems.first { $0.id == leaderID }
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
                onOpen: DestinationOrbitBuilder.children(of: selectedItem.node, from: library.artifacts).isEmpty
                    ? nil : { open(selectedItem) },
                onViewSaves: { presentedDestination = selectedItem.node }
            )
            .accessibilityElement(children: .contain)
            .accessibilityFocused($isDetailFocused)
            .transition(cardTransition)
        } else if presentation == .insight, let insight = homeInsight,
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
        guard let parent = fieldPath.last else { return orbitItems }
        return items(for: DestinationOrbitBuilder.children(of: parent.node, from: library.artifacts))
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
        guard fieldPath.isEmpty, homeInsight != nil else { return }
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

                    HStack(spacing: 8) {
                        resolutionMenu

                        if homeInsight != nil {
                            Button(action: showInsight) {
                                Group {
                                    if dynamicTypeSize.isAccessibilitySize {
                                        Image(systemName: "chart.bar.xaxis")
                                    } else {
                                        Label("Insight", systemImage: "chart.bar.xaxis")
                                    }
                                }
                                    .font(.subheadline.weight(.medium))
                                    .dynamicTypeSize(.large)
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
            }

            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
    }

    private var resolutionMenu: some View {
        Menu {
            Picker("Orbit Resolution", selection: Binding(
                get: { resolutionMode },
                set: { resolutionMode = $0 }
            )) {
                ForEach(OrbitResolutionMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
        } label: {
            Image(systemName: "scope")
                .font(.system(size: 17, weight: .medium))
                .dynamicTypeSize(.large)
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.08), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Orbit Resolution")
        .accessibilityValue(resolutionMode.displayName)
        .accessibilityHint("Changes how destinations are grouped")
    }
}

private enum HomePresentation: Equatable {
    case field
    case destination(UUID)
    case insight
}

#Preview {
    HomeView(library: ArtifactLibrary(repository: PreviewArtifactRepository()), onSave: {})
}
