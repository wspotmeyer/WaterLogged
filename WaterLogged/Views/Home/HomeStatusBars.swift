//
//  HomeStatusBars.swift
//  WaterLogged
//
//  Created by John Meyer on 7/2/26.
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

import SwiftUI
import SwiftData

// MARK: - Welcome Bar

/// A message bar shown when no dives exist, directing the user to get started.
/// Overlaid on the map by `HomeMapView`.
struct WelcomeBar: View {
	/// Whether this launch's container syncs through iCloud. The sync mode is fixed
	/// for the session (see `WaterLoggedStore`), so this doesn't need to be observed.
	var isCloudSyncActive = WaterLoggedStore.isCloudSyncActive

	/// The getting-started text. While iCloud sync is on, an empty log book may just
	/// mean dives from another device haven't downloaded yet, so say that first
	/// instead of suggesting the user turn sync on.
	static func message(isCloudSyncActive: Bool) -> String {
		isCloudSyncActive
		? "Your log book will appear here once iCloud finishes syncing. You can also enter or import dives from the Dives tab."
		: "Enter or import dives from the Dives tab, restore a backup from Tools, or turn on iCloud sync in Settings to bring in your log book from another device."
	}

	var body: some View {
		GlassEffectContainer {
			VStack(spacing: 4) {
				Text("Welcome to WaterLogged")
					.font(.headline)
				Text(Self.message(isCloudSyncActive: isCloudSyncActive))
					.font(.caption)
					.opacity(0.7)
					.multilineTextAlignment(.center)
			}
			.foregroundStyle(.white)
			.shadow(color: .black.opacity(0.8), radius: 2, y: 1)
			.padding()
			.glassEffect(.clear, in: .rect(cornerRadius: 24))
		}
		.padding(.horizontal)
	}
}

// MARK: - Statistics Bar

/// A mini stats overview overlaid on the map by `HomeMapView`.
///
/// The three core stats (Dives, Years, Countries) always show. On displays with
/// enough horizontal room the bar also surfaces Bottom Time, Max Depth, and
/// Trips; on narrower screens those extra stats are dropped via `ViewThatFits`.
struct StatisticsBar: View {
	@Query(sort: \Dive.date) var dives: [Dive]
	@Query var trips: [Trip]
	@AppStorage("unitSystem") private var unitSystem: UnitSystem = .imperial
	@AppStorage(PriorDiveHistory.diveCountKey) private var priorDiveCount = 0
	@AppStorage(PriorDiveHistory.bottomTimeMinutesKey) private var priorBottomTimeMinutes = 0

	private var units: UnitFormatter { UnitFormatter(system: unitSystem) }

	/// Dives and bottom time from before the log book began, added to the totals.
	private var priorHistory: PriorDiveHistory {
		PriorDiveHistory(diveCount: priorDiveCount, bottomTimeMinutes: priorBottomTimeMinutes)
	}

	private var yearsDiving: Int {
		guard let firstDate = dives.first?.date else { return 0 }
		return Calendar.current.dateComponents([.year], from: firstDate, to: .now).year ?? 0
	}

	private var countriesVisited: Int {
		StatsSnapshotBuilder.countriesVisited(in: dives)
	}

	private var deepestDepth: String {
		guard let maxMeters = StatsSnapshotBuilder.deepestDepthMeters(of: dives) else { return "—" }
		return units.depthString(maxMeters)
	}

	private var totalBottomTime: String {
		StatsSnapshotBuilder.formatBottomTime(
			priorHistory.totalBottomTimeSeconds(logged: StatsSnapshotBuilder.loggedBottomTimeSeconds(of: dives))
		)
	}

	/// The core stats always shown, followed by the extras that appear only when
	/// there is room. `ViewThatFits` prefers the full set and falls back to the
	/// core three.
	private var coreStatistics: [HomeStatistic] {
		[
			HomeStatistic(value: "\(priorHistory.totalDives(logged: dives.count))", label: "Dives"),
			HomeStatistic(value: "\(yearsDiving)", label: "Years"),
			HomeStatistic(value: "\(countriesVisited)", label: "Countries")
		]
	}

	private var allStatistics: [HomeStatistic] {
		coreStatistics + [
			HomeStatistic(value: totalBottomTime, label: "Bottom Time"),
			HomeStatistic(value: deepestDepth, label: "Max Depth"),
			HomeStatistic(value: "\(trips.count)", label: "Trips")
		]
	}

	var body: some View {
		GlassEffectContainer {
			ViewThatFits(in: .horizontal) {
				StatisticRow(statistics: allStatistics)
				StatisticRow(statistics: coreStatistics)
			}
			.padding()
			.glassEffect(.clear, in: .rect(cornerRadius: 24))
		}
		.padding(.horizontal)
	}
}

/// A single statistic's display value and caption.
private struct HomeStatistic: Identifiable {
	var id: String { label }
	let value: String
	let label: String
}

/// A horizontal row of statistic labels.
private struct StatisticRow: View {
	let statistics: [HomeStatistic]

	var body: some View {
		HStack(spacing: 12) {
			ForEach(statistics) { statistic in
				StatisticLabel(value: statistic.value, label: statistic.label)
			}
		}
	}
}

/// A compact label showing a prominent number with a caption underneath.
private struct StatisticLabel: View {
	let value: String
	let label: String

	var body: some View {
		VStack(spacing: 4) {
			Text(value)
				.font(.title)
				.bold()
				.fontDesign(.rounded)
				.monospacedDigit()
				.lineLimit(1)
				.minimumScaleFactor(0.8)
			Text(label)
				.font(.caption)
				.opacity(0.7)
				.lineLimit(1)
				.minimumScaleFactor(0.8)
		}
		.foregroundStyle(.white)
		.shadow(color: .black.opacity(0.8), radius: 2, y: 1)
		.padding(.vertical, 12)
		.frame(width: 90)
		.background(.black.opacity(0.2), in: .rect(cornerRadius: 12))
	}
}

#Preview {
	StatisticsBar()
		.modelContainer(PreviewContainer.container)
}

#Preview("Welcome") {
	WelcomeBar(isCloudSyncActive: false)
		.padding()
		.background(.blue.gradient)
}

#Preview("Welcome, Syncing") {
	WelcomeBar(isCloudSyncActive: true)
		.padding()
		.background(.blue.gradient)
}
