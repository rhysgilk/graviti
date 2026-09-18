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

    init(repository: any ArtifactRepository) {
        _library = StateObject(wrappedValue: ArtifactLibrary(repository: repository))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "circle.grid.cross")
                }
                .tag(AppTab.home)

            PlaceholderFeatureView(
                title: "Explore",
                icon: "sparkles"
            )
            .tabItem {
                Label("Explore", systemImage: "sparkles")
            }
            .tag(AppTab.explore)

            SaveView(library: library) {
                libraryNavigationResetID = UUID()
                selectedTab = .library
            }
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

            PlaceholderFeatureView(
                title: "Search",
                icon: "magnifyingglass"
            )
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }
            .tag(AppTab.search)
        }
        .tint(GravitiColors.iris)
        .preferredColorScheme(.dark)
        .task {
            await library.load()
            await library.importSharedArtifacts()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await library.importSharedArtifacts() }
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

private struct PlaceholderFeatureView: View {
    let title: String
    let icon: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 34))
                    .foregroundStyle(GravitiColors.iris)

                Text(title)
                    .font(.title2.weight(.semibold))
            }
            .navigationTitle(title)
        }
    }
}

#Preview {
    ContentView(repository: PreviewArtifactRepository())
}
