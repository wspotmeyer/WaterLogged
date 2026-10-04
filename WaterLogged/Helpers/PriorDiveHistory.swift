//
//  PriorDiveHistory.swift
//  WaterLogged
//
//  Created by John Meyer on 9/25/26.
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

/// Dives and bottom time the diver logged before their first entry in WaterLogged — for divers
/// whose earlier records are partial, on paper, or spread across other apps. These are added to
/// the logbook-wide totals (dive count and bottom time) wherever statistics are displayed.
///
/// Both values are stored in `UserDefaults` under `diveCountKey` and `bottomTimeMinutesKey`,
/// read by SwiftUI through `@AppStorage` and by non-view code through `current`. `nonisolated`
/// so the nonisolated `WaterLoggedStore.registerDefaults()` can reference the keys.
nonisolated struct PriorDiveHistory: Equatable, Sendable {
	static let diveCountKey = "priorDiveCount"
	static let bottomTimeMinutesKey = "priorBottomTimeMinutes"

	/// No prior history; totals are the logbook's alone.
	static let none = PriorDiveHistory()

	var diveCount: Int = 0
	var bottomTimeMinutes: Int = 0

	/// Reads the stored values for code outside the SwiftUI view tree (e.g. the widget coordinator).
	/// `UserDefaults.integer(forKey:)` falls back to 0, matching the `@AppStorage` defaults.
	static var current: PriorDiveHistory {
		PriorDiveHistory(
			diveCount: UserDefaults.standard.integer(forKey: diveCountKey),
			bottomTimeMinutes: UserDefaults.standard.integer(forKey: bottomTimeMinutesKey)
		)
	}

	/// Prior bottom time in seconds, the unit `Dive.durationSeconds` uses. Negative stored values
	/// are treated as zero so a bad entry can never reduce the logbook's own totals.
	var bottomTimeSeconds: Int {
		max(bottomTimeMinutes, 0) * 60
	}

	/// The whole-hours part of the prior bottom time, for editing as hours and minutes.
	var bottomTimeHoursComponent: Int {
		get { max(bottomTimeMinutes, 0) / 60 }
		set { bottomTimeMinutes = max(newValue, 0) * 60 + bottomTimeMinutesComponent }
	}

	/// The leftover-minutes part of the prior bottom time. Entering 60 or more rolls over into
	/// hours, so "90" minutes becomes 1h 30m.
	var bottomTimeMinutesComponent: Int {
		get { max(bottomTimeMinutes, 0) % 60 }
		set { bottomTimeMinutes = bottomTimeHoursComponent * 60 + max(newValue, 0) }
	}

	/// `loggedDives` plus the prior dive count.
	func totalDives(logged loggedDives: Int) -> Int {
		loggedDives + max(diveCount, 0)
	}

	/// `loggedSeconds` of bottom time plus the prior bottom time, in seconds.
	func totalBottomTimeSeconds(logged loggedSeconds: Int) -> Int {
		loggedSeconds + bottomTimeSeconds
	}
}
