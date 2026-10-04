//
//  WaterLoggedApp.swift
//  WaterLogged
//
//  Created by John Meyer on 2/23/26.
//
//  Copyright © 2026 John Meyer.
//
//  This file is part of WaterLogged, a scuba dive logging application written by John Meyer.
//
//  WaterLogged is free software: you can redistribute it and/or modify it under the terms of the GNU
//  General Public License as published by the Free Software Foundation, either version 3 of the License,
//  or (at your option) any later version.
//
//  WaterLogged is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
//  even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
//  General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along with WaterLogged. If not,
//  see <https://www.gnu.org/licenses/>.

import AppIntents
import SwiftUI
import SwiftData

@main
struct WaterLoggedApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
#if os(macOS)
    @AppStorage("toolbarLabelStyle") private var toolbarLabelStyle: ToolbarLabelStyle = .automatic
    @State private var newItemIntent = NewItemIntent()
#endif

    /// Seeds `UserDefaults.standard` with the same defaults the SwiftUI
    /// view tree uses via `@AppStorage`, so any non-SwiftUI consumer
    /// (AppIntents, notification handlers, future widgets, etc.) can read
    /// raw values without each one having to maintain its own fallback.
    /// See `WaterLoggedStore.registerDefaults()` for the rationale.
    init() {
        WaterLoggedStore.registerDefaults()

        // Started before the container exists so the first sync events are
        // caught. Inert when sync is off, since CloudKit then posts nothing.
        CloudSyncMonitor.shared.start(onDownload: Self.handleSyncedDownload)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
#if os(macOS)
                .environment(newItemIntent)
#endif
                .preferredColorScheme(appearanceMode.colorScheme)
                .task {
                    Self.mergeSyncedDuplicates()

                    // Donate dive sites, trips, and buddies to the Spotlight
                    // index so they're findable in system search; tapping a
                    // result opens its detail view via the per-type OpenIntent.
                    // Indexing is best-effort; failures shouldn't block launch.
                    try? await SpotlightIndexer.indexAll()

                    // Keep the index in sync with every subsequent save/edit/
                    // delete for the rest of the session (idempotent).
                    SpotlightIndexCoordinator.shared.start()

                    // Write an initial statistics snapshot for the home-screen
                    // widget and keep it current as the logbook changes.
                    StatsWidgetCoordinator.shared.refreshNow()
                    StatsWidgetCoordinator.shared.start()
                }
                .onChange(of: scenePhase) { _, phase in
                    // Rebuild the widget snapshot when returning to the
                    // foreground so unit-system changes made in the app's
                    // Settings screen are reflected in the widget.
                    if phase == .active {
                        StatsWidgetCoordinator.shared.refreshNow()
                        Self.mergeSyncedDuplicates()
                    }
                }
        }
        .modelContainer(WaterLoggedStore.shared)
#if os(macOS)
        .windowToolbarLabelStyle($toolbarLabelStyle)
        .commands {
            FileMenuCommands(intent: newItemIntent)
            AboutCommands()
            HelpCommands()
        }
#endif

#if os(macOS)
        Settings {
            SettingsView()
                .frame(width: 400)
                .modelContainer(WaterLoggedStore.shared)
                .preferredColorScheme(appearanceMode.colorScheme)
        }

        Window("About WaterLogged", id: AboutView.windowID) {
            AboutView()
                .preferredColorScheme(appearanceMode.colorScheme)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 360, height: 480)
#endif
    }

    /// Runs after iCloud downloads changes from another device. Those records
    /// don't post `ModelContext.didSave`, so the save-driven coordinators
    /// have to be told; both debounce, so the many downloads of a first sync
    /// collapse into one pass each.
    private static func handleSyncedDownload() {
        mergeSyncedDuplicates()
        SpotlightIndexCoordinator.shared.refreshForSyncedChanges()
        StatsWidgetCoordinator.shared.refreshForSyncedChanges()
    }

    /// With iCloud sync on, an owner profile or gas mix created on two devices
    /// before their first sync arrives as two records; fold them back into one.
    /// Runs at launch, on foregrounding, and after each download.
    /// `LogbookOwner.fetchOrCreate` also merges, so the owner screens heal
    /// themselves in between.
    private static func mergeSyncedDuplicates() {
        guard WaterLoggedStore.isCloudSyncActive else { return }
        let context = WaterLoggedStore.shared.mainContext
        do {
            try LogbookOwner.mergeDuplicates(in: context)
            try GasMix.mergeDuplicates(in: context)
            if context.hasChanges {
                try context.save()
            }
        } catch {
            print("Failed to merge duplicate synced records: \(error)")
        }
    }
}
