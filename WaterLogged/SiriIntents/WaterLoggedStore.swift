//
//  WaterLoggedStore.swift
//  WaterLogged
//
//  Created by John Meyer on 6/8/26.
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
//

import Foundation
import SwiftData

/// Shared SwiftData container and helpers used by both the SwiftUI view tree
/// and the AppIntents query layer. Centralizing the container here keeps a
/// single store and a single CloudKit sync source per process — important once
/// iCloud sync is enabled, since two containers pointing at the same store
/// would race on writes and double-sync to CloudKit.
nonisolated enum WaterLoggedStore {

	/// Every `@Model` type WaterLogged persists. Must mirror the schema passed
	/// to `.modelContainer(_:)` in `WaterLoggedApp` — kept here so there's one
	/// source of truth.
	static let schema = Schema([
		Dive.self,
		DiveSite.self,
		GasMix.self,
		DepthSample.self,
		Equipment.self,
		ServiceRecord.self,
		Certification.self,
		Buddy.self,
		Trip.self,
		LogbookOwner.self,
		Photo.self,
		Tank.self
	])

	/// `UserDefaults` key for the user's "Sync with iCloud" preference. Off by default.
	static let iCloudSyncEnabledKey = "iCloudSyncEnabled"

	/// The CloudKit container the logbook syncs through. It must match the
	/// container in the app's iCloud capability (Signing & Capabilities).
	static let cloudKitContainerIdentifier = "iCloud.net.wspot.WaterLogged"

	/// Process-wide container. Uses default `ModelConfiguration` so the
	/// on-disk store URL matches what `.modelContainer(for:)` previously
	/// produced (preserving existing user data).
	static var shared: ModelContainer { launchStore.container }

	/// Whether the user's iCloud sync preference was on when this process
	/// created its container. Settings compares this with the live preference
	/// to tell the user a relaunch is needed.
	static var launchedWithCloudSyncEnabled: Bool { launchStore.requestedCloudSync }

	/// Whether the container is actually syncing through CloudKit. Can be
	/// `false` even when sync was requested, if CloudKit couldn't be set up.
	static var isCloudSyncActive: Bool { launchStore.isCloudSyncActive }

	/// The container, built once per process from the iCloud preference read
	/// at launch. The choice can't change mid-session: the view tree,
	/// AppIntents, and Spotlight indexing all share this one container, so a
	/// change to the preference takes effect at the next launch.
	///
	/// `cloudKitDatabase` is always explicit (never `.automatic`) so sync is
	/// opt-in rather than switched on by the mere presence of the iCloud
	/// entitlement. Both modes open the same store file, so turning sync off
	/// keeps everything already on the device.
	private static let launchStore: LaunchStore = {
		let requested = UserDefaults.standard.bool(forKey: iCloudSyncEnabledKey)
		if requested {
			do {
				let configuration = ModelConfiguration(
					schema: schema,
					cloudKitDatabase: .private(cloudKitContainerIdentifier)
				)
				let container = try ModelContainer(for: schema, configurations: configuration)
				return LaunchStore(container: container, requestedCloudSync: true, isCloudSyncActive: true)
			} catch {
				// Most likely a missing iCloud entitlement or container. Opening
				// the logbook locally beats failing to launch; Settings reports
				// that sync couldn't start.
				print("iCloud sync unavailable, opening the local store instead: \(error)")
			}
		}
		do {
			let configuration = ModelConfiguration(
				schema: schema,
				cloudKitDatabase: .none
			)
			let container = try ModelContainer(for: schema, configurations: configuration)
			return LaunchStore(container: container, requestedCloudSync: requested, isCloudSyncActive: false)
		} catch {
			fatalError("Failed to create WaterLogged ModelContainer: \(error)")
		}
	}()

	/// The container plus the sync state it was created with.
	private struct LaunchStore: Sendable {
		let container: ModelContainer
		let requestedCloudSync: Bool
		let isCloudSyncActive: Bool
	}

	/// Reads the user's preferred unit system out of UserDefaults so AppIntent
	/// responses (which may run outside the SwiftUI view tree) can format
	/// values in the unit the user sees inside the app.
	///
	/// Relies on `registerDefaults()` having been called at launch to seed
	/// the fallback; the local `?? .imperial` is a defensive backstop in
	/// case this is read before registration completes (e.g. from a unit
	/// test that doesn't invoke `WaterLoggedApp`).
	static var preferredUnitSystem: UnitSystem {
		let raw = UserDefaults.standard.string(forKey: "unitSystem") ?? UnitSystem.imperial.rawValue
		return UnitSystem(rawValue: raw) ?? .imperial
	}

	/// Registers default values for any `UserDefaults` key that the app
	/// exposes via `@AppStorage`. Must be called once at app launch
	/// (`WaterLoggedApp.init`) before any non-SwiftUI consumer reads
	/// `UserDefaults.standard`.
	///
	/// Why this is needed:
	/// - `@AppStorage("foo") var foo: T = defaultValue` only stores
	///   `defaultValue` into the SwiftUI binding — it does **not** write
	///   the default into `UserDefaults` itself. The raw store stays empty
	///   until the user actively changes the setting.
	/// - Consequently, anything reading the raw store from outside the
	///   view tree (AppIntents, notification handlers, widgets, background
	///   tasks) sees `nil` for keys the user hasn't toggled, and must
	///   either reimplement the same fallback (fragile — easy to drift)
	///   or rely on `UserDefaults.standard.register(defaults:)`, which
	///   installs the values in the volatile defaults domain so reads
	///   return them transparently.
	///
	/// IMPORTANT: every key/value pair below MUST stay in sync with the
	/// corresponding `@AppStorage("<key>") var ... = <default>` used in
	/// the SwiftUI view tree (search for `@AppStorage` to find them).
	static func registerDefaults() {
		UserDefaults.standard.register(defaults: [
			// Mirrored from @AppStorage("unitSystem") = .imperial in
			// SettingsView, DiveDetailView, StatsView, DepthProfileChart,
			// DiveListView, DiveEntryView, GasMixDetailView,
			// EquipmentListView, BulkUpdateView, SamplesToolView,
			// DiveTransferRowView, etc.
			"unitSystem": UnitSystem.imperial.rawValue,

			// Mirrored from @AppStorage("appearanceMode") = .system in
			// WaterLoggedApp and SettingsView.
			"appearanceMode": AppearanceMode.system.rawValue,

			// Mirrored from @AppStorage(PriorDiveHistory.diveCountKey) = 0 and
			// @AppStorage(PriorDiveHistory.bottomTimeMinutesKey) = 0 in
			// PriorDiveHistorySection, StatsView, StatisticsBar, and DiveDetailView.
			PriorDiveHistory.diveCountKey: 0,
			PriorDiveHistory.bottomTimeMinutesKey: 0,

			// Mirrored from @AppStorage(WaterLoggedStore.iCloudSyncEnabledKey)
			// = false in CloudSyncSection.
			iCloudSyncEnabledKey: false
		])
	}
}
