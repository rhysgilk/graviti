//
//  ContentView.swift
//  graviti
//
//  Created by Rhys Gilkenson on 9/17/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var library: ArtifactLibrary
    @State private var selectedTab: AppTab = .home
    @State private var libraryNavigationResetID = UUID()
    @State private var searchQuery = ""
    @AppStorage("onboarding.completed") private var hasCompletedOnboarding = false
    @State private var shareImportNotice: String?

    init(repository: any ArtifactRepository) {
        _library = StateObject(wrappedValue: ArtifactLibrary(repository: repository))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(library: library) { selectedTab = .search }
                .tabItem {
                    Label("Home", systemImage: "circle.grid.cross")
                }
                .tag(AppTab.home)

            ExploreView(library: library) { destination in
                searchQuery = destination
                selectedTab = .search
            }
            .tabItem {
                Label("Explore", systemImage: "sparkles")
            }
            .tag(AppTab.explore)

            SaveView(library: library, onViewLibrary: {
                libraryNavigationResetID = UUID()
                selectedTab = .library
            }, onFindPlace: {
                selectedTab = .search
            })
            .tabItem {
                Label("Save", systemImage: "plus.circle.fill")
            }
            .tag(AppTab.save)

            LibraryView(library: library)
            .id(libraryNavigationResetID)
            .tabItem {
                Label("Library", systemImage: "square.stack")
            }
            .tag(AppTab.library)

            SearchView(library: library, provider: MapKitPlaceSearchProvider(), query: $searchQuery)
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }
            .tag(AppTab.search)
        }
        .tint(GravitiColors.iris)
        .preferredColorScheme(.dark)
        .overlay(alignment: .top) {
            if let shareImportNotice {
                Label(shareImportNotice, systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 48)
                    .background(GravitiColors.deepInk.opacity(0.98), in: Capsule())
                    .overlay(Capsule().strokeBorder(GravitiColors.signalMint.opacity(0.5)))
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .fullScreenCover(isPresented: onboardingPresented) {
            OnboardingView(
                onFindPlace: {
                    hasCompletedOnboarding = true
                    searchQuery = ""
                    selectedTab = .search
                },
                onSaveOrImport: {
                    hasCompletedOnboarding = true
                    selectedTab = .save
                },
                onExplore: {
                    hasCompletedOnboarding = true
                    selectedTab = .home
                }
            )
            .interactiveDismissDisabled()
        }
        .task {
            await library.load()
            await importSharedArtifactsWithNotice()
            await library.processPendingMaps()
            library.processPendingEnrichment()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await importSharedArtifactsWithNotice()
                await library.processPendingMaps()
                library.processPendingEnrichment()
            }
        }
    }

    private var onboardingPresented: Binding<Bool> {
        Binding(
            get: { !hasCompletedOnboarding },
            set: { presented in
                if !presented { hasCompletedOnboarding = true }
            }
        )
    }

    private func importSharedArtifactsWithNotice() async {
        let count = await library.importSharedArtifacts()
        guard count > 0 else { return }
        let notice = "Added \(count) shared \(count == 1 ? "save" : "saves") to your Library"
        withAnimation(.easeOut(duration: 0.25)) {
            shareImportNotice = notice
        }
        try? await Task.sleep(for: .seconds(4))
        guard shareImportNotice == notice else { return }
        withAnimation(.easeIn(duration: 0.2)) {
            shareImportNotice = nil
        }
    }
}

private enum AppTab: Hashable {
    case home
    case explore
    case save
    case library
    case search
}

#Preview {
    ContentView(repository: PreviewArtifactRepository())
}
