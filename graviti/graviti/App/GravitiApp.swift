//
//  gravitiApp.swift
//  graviti
//
//  Created by Rhys Gilkenson on 9/17/26.
//

import SwiftUI
import SwiftData

@main
struct GravitiApp: App {
    private let repository: SwiftDataArtifactRepository?
    private let startupError: String?

    init() {
        do {
            let container = try ModelContainer(for: StoredArtifact.self)
            repository = SwiftDataArtifactRepository(context: ModelContext(container))
            startupError = nil
        } catch {
            repository = nil
            startupError = error.localizedDescription
        }
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
