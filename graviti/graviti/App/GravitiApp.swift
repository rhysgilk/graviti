//
//  gravitiApp.swift
//  graviti
//
//  Created by Rhys Gilkenson on 9/17/26.
//

import SwiftUI
import SwiftData
import UIKit

@main
struct GravitiApp: App {
    private let repository: SwiftDataArtifactRepository?
    private let startupError: String?

    init() {
        Self.configureTypography()
        do {
            let container = try ModelContainer(for: StoredArtifact.self)
            repository = SwiftDataArtifactRepository(context: ModelContext(container))
            startupError = nil
        } catch {
            repository = nil
            startupError = error.localizedDescription
        }
    }

    private static func configureTypography() {
        guard let regular = UIFont(name: "Sora-Regular", size: 15),
              let semibold = UIFont(name: "Sora-SemiBold", size: 17),
              let largeTitle = UIFont(name: "Sora-SemiBold", size: 34) else { return }
        UINavigationBar.appearance().titleTextAttributes = [.font: semibold]
        UINavigationBar.appearance().largeTitleTextAttributes = [.font: largeTitle]
        UITabBarItem.appearance().setTitleTextAttributes([.font: regular.withSize(10)], for: .normal)
        UITabBarItem.appearance().setTitleTextAttributes([.font: semibold.withSize(10)], for: .selected)
        UISegmentedControl.appearance().setTitleTextAttributes([.font: regular.withSize(13)], for: .normal)
        UISegmentedControl.appearance().setTitleTextAttributes([.font: semibold.withSize(13)], for: .selected)
        UISearchTextField.appearance().font = regular
    }

    var body: some Scene {
        WindowGroup {
            if let repository {
                ContentView(repository: repository)
            } else {
                ContentUnavailableView(
                    "Library unavailable",
                    systemImage: "externaldrive.badge.exclamationmark",
                    description: Text(startupError ?? String(localized: "The local library could not open."))
                )
            }
        }
    }
}
