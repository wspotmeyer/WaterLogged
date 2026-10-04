//
//  StatsSnapshotBuilder.swift
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

/// Builds a `StatsSnapshot` from the logbook's dives and trips. Kept as a pure
/// function (no SwiftData fetching, no I/O) so it mirrors the computations in
/// `StatsView` and stays unit-testable. `StatsWidgetCoordinator` supplies the
/// fetched models; `WidgetCenter` reload and persistence happen there.
enum StatsSnapshotBuilder {
	/// Computes a display-ready snapshot. Depth and bottom-time are formatted in
	/// `unitSystem` here so the widget renders strings without needing
	/// `UnitFormatter`. `priorHistory` is added to the dive count and bottom time.
	static func makeSnapshot(
		dives: [Dive],
		trips: [Trip],
		priorHistory: PriorDiveHistory = .none,
		unitSystem: UnitSystem,
		updatedAt: Date
	) -> StatsSnapshot {
		let units = UnitFormatter(system: unitSystem)

		let deepest: String
		if let maxMeters = deepestDepthMeters(of: dives) {
			deepest = units.depthString(maxMeters)
		} else {
			deepest = "—"
		}

		let totalSeconds = priorHistory.totalBottomTimeSeconds(logged: loggedBottomTimeSeconds(of: dives))

		let countries = countriesVisited(in: dives)
		let sites = diveSitesVisited(in: dives)

		return StatsSnapshot(
			totalDives: priorHistory.totalDives(logged: dives.count),
			deepestDepthDisplay: deepest,
			totalBottomTimeDisplay: formatBottomTime(totalSeconds),
			countriesVisited: countries,
			diveSitesVisited: sites,
			tripsVisited: trips.count,
			updatedAt: updatedAt
		)
	}

	// MARK: - Logbook-wide counts
	//
	// Shared by the widget snapshot, `StatsView` and the home screen's
	// `StatisticsBar` so all three always agree.

	/// The deepest maximum depth among `dives`, in meters; `nil` with no dives.
	static func deepestDepthMeters(of dives: [Dive]) -> Double? {
		dives.map(\.maxDepthMeters).max()
	}

	/// Total bottom time of the logged dives, in seconds (prior history excluded).
	static func loggedBottomTimeSeconds(of dives: [Dive]) -> Int {
		dives.reduce(0) { $0 + $1.durationSeconds }
	}

	/// Number of distinct, non-empty site countries among `dives`.
	static func countriesVisited(in dives: [Dive]) -> Int {
		Set(dives.compactMap { $0.site?.country }.filter { !$0.isEmpty }).count
	}

	/// Number of distinct dive sites among `dives`.
	static func diveSitesVisited(in dives: [Dive]) -> Int {
		Set(dives.compactMap { $0.site?.externalId }).count
	}

	/// Formats a total number of seconds as `"Hh"` once it reaches an hour, or
	/// `"Mm"` when under an hour — the compact form used by the widgets and the
	/// home screen's statistics bar. (`StatsView` shows the longer `"Hh Mm"`.)
	static func formatBottomTime(_ seconds: Int) -> String {
		let hours = seconds / 3600
		let minutes = (seconds % 3600) / 60
		if hours > 0 {
			return "\(hours)h"
		}
		return "\(minutes)m"
	}
}
