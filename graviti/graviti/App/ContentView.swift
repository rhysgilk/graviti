//
//  ContentView.swift
//  graviti
//
//  Created by Rhys Gilkenson on 9/17/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "circle.grid.cross")
                }

            PlaceholderFeatureView(
                title: "Explore",
                icon: "sparkles"
            )
            .tabItem {
                Label("Explore", systemImage: "sparkles")
            }

            PlaceholderFeatureView(
                title: "Save",
                icon: "plus.circle"
            )
            .tabItem {
                Label("Save", systemImage: "plus.circle.fill")
            }

            PlaceholderFeatureView(
                title: "Library",
                icon: "square.stack"
            )
            .tabItem {
                Label("Library", systemImage: "square.stack")
            }

            PlaceholderFeatureView(
                title: "Search",
                icon: "magnifyingglass"
            )
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }
        }
        .tint(GravitiColors.iris)
    }
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
    ContentView()
}
