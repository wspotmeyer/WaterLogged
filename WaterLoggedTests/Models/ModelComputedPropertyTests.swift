//
//  ModelComputedPropertyTests.swift
//  WaterLoggedTests
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
import SwiftData
@testable import WaterLogged

/// Computed properties that depend on to-many relationships, exercised through
/// a live in-memory context so the relationships resolve correctly.
@MainActor
@Suite
struct ModelComputedPropertyTests {

	// `container` must be stored: a ModelContext does not retain its container.
	let container: ModelContainer
	let context: ModelContext

	init() throws {
		container = try TestModelContainer.make()
		context = container.mainContext
	}

	// MARK: - totalDiveTimeSeconds

	@Test func siteTotalDiveTimeSumsLinkedDives() throws {
		let site = DiveSite(name: "Reef")
		context.insert(site)
		for seconds in [1200, 1800, 600] {
			let dive = Dive(durationSeconds: seconds, site: site)
			context.insert(dive)
		}
		try context.save()
		#expect(DivesSection.totalDiveTimeSeconds(for: site.dives ?? []) == 3600)
	}

	@Test func tripDiveCountAndTotalTime() throws {
		let trip = Trip(name: "Trip")
		context.insert(trip)
		let d1 = Dive(durationSeconds: 1000, trip: trip)
		let d2 = Dive(durationSeconds: 2000, trip: trip)
		context.insert(d1)
		context.insert(d2)
		try context.save()
		#expect(trip.diveCount == 2)
		#expect(DivesSection.totalDiveTimeSeconds(for: trip.dives ?? []) == 3000)
	}

	// MARK: - Gas mix nitrogen balance

	@Test func gasMixNitrogenIsTheBalanceOfTheOtherGases() {
		#expect(GasMix.nitrogenPercent(oxygen: 21) == 79)
		#expect(GasMix.nitrogenPercent(oxygen: 32) == 68)
		#expect(GasMix.nitrogenPercent(oxygen: 21, helium: 35) == 44)
		#expect(GasMix.nitrogenPercent(oxygen: 100) == 0)
		// A mix that already exceeds 100% clamps rather than reporting negative nitrogen.
		#expect(GasMix.nitrogenPercent(oxygen: 80, helium: 40) == 0)
	}

	@Test func gasMixComponentsIncludeDerivedNitrogen() throws {
		let gas = GasMix(name: "EAN32", oxygenPercent: 32)
		let nitrogen = try #require(gas.components.first { $0.kind == .nitrogen })
		#expect(nitrogen.fraction == 0.68)
		#expect(gas.nitrogenPercent == 68)
	}

	@Test func gasMixOmitsNitrogenFromPureOxygen() {
		let gas = GasMix(name: "Oxygen", oxygenPercent: 100)
		#expect(gas.components.map(\.kind) == [.oxygen])
	}

	@Test func gasMixTotalDiveTimeCountsEachDiveOnce() throws {
		let gas = GasMix(name: "EAN32", oxygenPercent: 32)
		context.insert(gas)
		let dive = Dive(durationSeconds: 1500)
		context.insert(dive)
		// Two tanks on the same dive using the same gas — dive counted once.
		for _ in 0..<2 {
			let tank = Tank(gasMix: gas, startPressureBar: 200, endPressureBar: 50)
			tank.dive = dive
			context.insert(tank)
		}
		try context.save()
		#expect(gas.dives.count == 1)
		#expect(DivesSection.totalDiveTimeSeconds(for: gas.dives) == 1500)
	}

	// MARK: - Names & display

	@Test func buddyFormattedNameIncludesBothNames() {
		let buddy = Buddy(givenName: "Alex", familyName: "Fisher")
		let name = buddy.formattedName
		#expect(name.localizedStandardContains("Alex"))
		#expect(name.localizedStandardContains("Fisher"))
	}

	@Test func ownerFormattedNameFallsBackToGivenName() {
		let owner = LogbookOwner(givenName: "Jane", familyName: "")
		#expect(owner.formattedName.localizedStandardContains("Jane"))
	}

	@Test("GasMix displayName prefers the name, else oxygen percent", arguments: [
		(name: "EAN32", oxygen: 32.0, expected: "EAN32"),
		(name: "", oxygen: 21.0, expected: "O₂: 21%")
	])
	func gasMixDisplayName(name: String, oxygen: Double, expected: String) {
		let gas = GasMix(name: name, oxygenPercent: oxygen)
		#expect(gas.displayName == expected)
	}

	// MARK: - Trip URL & date range

	@Test func tripURLParsesValidStringAndRejectsEmpty() {
		#expect(Trip(name: "T", urlString: "https://example.com").url != nil)
		#expect(Trip(name: "T", urlString: "").url == nil)
	}

	@Test func tripDateRangeSingleDayShowsOneDate() {
		let day = Date(timeIntervalSince1970: 1_750_000_000)
		let trip = Trip(name: "T", startDate: day, endDate: day)
		// Start equals end, so the range collapses to a single formatted date.
		#expect(trip.dateRangeFormatted == day.formatted(date: .abbreviated, time: .omitted))
	}

	@Test func tripDateRangeMultiDayShowsSeparator() {
		let start = Date(timeIntervalSince1970: 1_750_000_000)
		let end = start.addingTimeInterval(6 * 86400)
		let trip = Trip(name: "T", startDate: start, endDate: end)
		#expect(trip.dateRangeFormatted.contains("–"))
	}
}
