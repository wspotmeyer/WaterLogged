//
//  StatsSnapshotBuilderTests.swift
//  WaterLoggedTests
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

import Testing
import Foundation
@testable import WaterLogged

@MainActor
struct StatsSnapshotBuilderTests {

	/// Three dives across two sites in two countries, plus two trips.
	private func makeSample() -> (dives: [Dive], trips: [Trip]) {
		let mexico = DiveSite(name: "Palancar Reef", country: "Mexico", region: "Cozumel")
		let egypt = DiveSite(name: "SS Thistlegorm", country: "Egypt", region: "Red Sea")

		let dives = [
			Dive(maxDepthMeters: 30.0, durationSeconds: 3600, site: mexico),
			Dive(maxDepthMeters: 18.0, durationSeconds: 1800, site: mexico),
			Dive(maxDepthMeters: 40.0, durationSeconds: 1200, site: egypt)
		]
		let trips = [
			Trip(name: "Cozumel", startDate: .distantPast, endDate: .distantPast),
			Trip(name: "Red Sea", startDate: .distantPast, endDate: .distantPast)
		]
		return (dives, trips)
	}

	@Test func countsAndAggregates() {
		let sample = makeSample()
		let snapshot = StatsSnapshotBuilder.makeSnapshot(
			dives: sample.dives, trips: sample.trips, unitSystem: .metric, updatedAt: .distantPast
		)

		#expect(snapshot.totalDives == 3)
		#expect(snapshot.countriesVisited == 2)   // Mexico, Egypt
		#expect(snapshot.diveSitesVisited == 2)   // two distinct sites
		#expect(snapshot.tripsVisited == 2)
		// 3600 + 1800 + 1200 = 6600s → compact "1h" (hours-only once ≥ 1h)
		#expect(snapshot.totalBottomTimeDisplay == "1h")
	}

	@Test func priorHistoryAddsToDivesAndBottomTime() {
		let sample = makeSample()
		let snapshot = StatsSnapshotBuilder.makeSnapshot(
			dives: sample.dives,
			trips: sample.trips,
			priorHistory: PriorDiveHistory(diveCount: 100, bottomTimeMinutes: 120),
			unitSystem: .metric,
			updatedAt: .distantPast
		)
		#expect(snapshot.totalDives == 103)
		// 6600s logged + 7200s prior = 13800s → "3h"
		#expect(snapshot.totalBottomTimeDisplay == "3h")
		// Prior history carries no sites or countries.
		#expect(snapshot.countriesVisited == 2)
		#expect(snapshot.diveSitesVisited == 2)
	}

	@Test func deepestDepthMetric() {
		let sample = makeSample()
		let snapshot = StatsSnapshotBuilder.makeSnapshot(
			dives: sample.dives, trips: sample.trips, unitSystem: .metric, updatedAt: .distantPast
		)
		#expect(snapshot.deepestDepthDisplay == "40 m")
	}

	@Test func deepestDepthImperial() {
		let sample = makeSample()
		let snapshot = StatsSnapshotBuilder.makeSnapshot(
			dives: sample.dives, trips: sample.trips, unitSystem: .imperial, updatedAt: .distantPast
		)
		// 40 m → 131.23 ft, formatted with 0 fraction digits.
		#expect(snapshot.deepestDepthDisplay == "131 ft")
	}

	@Test func emptyLogbook() {
		let snapshot = StatsSnapshotBuilder.makeSnapshot(
			dives: [], trips: [], unitSystem: .metric, updatedAt: .distantPast
		)
		#expect(snapshot.totalDives == 0)
		#expect(snapshot.deepestDepthDisplay == "—")
		#expect(snapshot.totalBottomTimeDisplay == "0m")
		#expect(snapshot.countriesVisited == 0)
		#expect(snapshot.diveSitesVisited == 0)
		#expect(snapshot.tripsVisited == 0)
	}

	@Test func bottomTimeUnderOneHour() {
		#expect(StatsSnapshotBuilder.formatBottomTime(2700) == "45m")
		#expect(StatsSnapshotBuilder.formatBottomTime(3600) == "1h")
		#expect(StatsSnapshotBuilder.formatBottomTime(6600) == "1h")
		#expect(StatsSnapshotBuilder.formatBottomTime(0) == "0m")
	}
}
