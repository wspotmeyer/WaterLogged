//
//  StatsSnapshot.swift
//  WaterLogged
//
//  Created by John Meyer on 6/28/26.
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

import Foundation

/// Constants shared between the WaterLogged app and its widget extension.
///
/// This file is a member of **both** the app target and the `WaterLoggedWidgets`
/// target so the snapshot contract lives in exactly one place. Everything is
/// `nonisolated` so it compiles cleanly under the app's
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` default as well as the widget
/// target's nonisolated default, and so the widget's `TimelineProvider` (which
/// runs off the main actor) can read a snapshot.
nonisolated enum WidgetShared {
	/// App Group both targets share. Must match the App Groups capability added
	/// to the app and widget targets in Signing & Capabilities.
	static let appGroupID = "group.net.wspot.WaterLogged"

	/// `UserDefaults` key under which the encoded `StatsSnapshot` is stored.
	static let snapshotKey = "statsSnapshot"

	/// URL a widget tap opens; the app routes `host == "stats"` to the Stats
	/// view. WidgetKit delivers this to the owning app without the scheme being
	/// registered in Info.plist.
	static let deepLinkString = "waterlogged://stats"
}

/// A small, display-ready summary of logbook statistics that the app computes
/// and writes to the shared App Group store, and the widget reads back.
///
/// Depth and bottom-time are stored as **pre-formatted strings** (already in the
/// user's unit system) so the widget needs no access to `UnitFormatter` or the
/// SwiftData store — it just renders what's here.
nonisolated struct StatsSnapshot: Codable, Sendable {
	var totalDives: Int
	var deepestDepthDisplay: String
	var totalBottomTimeDisplay: String
	var countriesVisited: Int
	var diveSitesVisited: Int
	var tripsVisited: Int
	var updatedAt: Date

	/// Empty-state value used for previews and before the app has written a
	/// real snapshot (e.g. a fresh install).
	static let placeholder = StatsSnapshot(
		totalDives: 0,
		deepestDepthDisplay: "—",
		totalBottomTimeDisplay: "—",
		countriesVisited: 0,
		diveSitesVisited: 0,
		tripsVisited: 0,
		updatedAt: .distantPast
	)

	/// Reads the latest snapshot from the shared App Group store, falling back
	/// to `.placeholder` if nothing has been written yet or the App Group is
	/// unreachable.
	static func load() -> StatsSnapshot {
		guard
			let defaults = UserDefaults(suiteName: WidgetShared.appGroupID),
			let data = defaults.data(forKey: WidgetShared.snapshotKey),
			let snapshot = try? JSONDecoder().decode(StatsSnapshot.self, from: data)
				else {
			return .placeholder
		}
		return snapshot
	}

	/// Writes this snapshot to the shared App Group store. No-op if the App
	/// Group is unreachable (e.g. capability missing) or encoding fails.
	func save() {
		guard
			let defaults = UserDefaults(suiteName: WidgetShared.appGroupID),
			let data = try? JSONEncoder().encode(self)
				else {
			return
		}
		defaults.set(data, forKey: WidgetShared.snapshotKey)
	}
}
