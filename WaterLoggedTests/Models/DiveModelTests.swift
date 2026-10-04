//
//  DiveModelTests.swift
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
@testable import WaterLogged

/// Pure computed-property tests on Dive that need no persistence.
struct DiveModelTests {

	// MARK: - displayTitle

	@Test func displayTitleUsesTitleWhenPresent() {
		let dive = Dive(title: "Palancar Caves")
		#expect(dive.displayTitle == "Palancar Caves")
	}

	@Test func displayTitleFallsBackToSiteName() {
		let site = DiveSite(name: "Blue Corner")
		let dive = Dive(title: "", site: site)
		#expect(dive.displayTitle == "Blue Corner")
	}

	@Test func displayTitleFallsBackToDiveNumber() {
		let dive = Dive(diveNumber: 17, title: "")
		#expect(dive.displayTitle == "Dive #17")
	}

	// MARK: - durationFormatted

	@Test("Duration formats across hour/minute/second boundaries", arguments: [
		(seconds: 45, expected: "45s"),
		(seconds: 125, expected: "2m 5s"),
		(seconds: 3661, expected: "1h 1m 1s"),
		(seconds: 0, expected: "0s")
	])
	func durationFormatted(seconds: Int, expected: String) {
		#expect(Dive(durationSeconds: seconds).durationFormatted == expected)
	}

	// MARK: - endDate

	@Test func endDateIsStartPlusDuration() {
		let start = Date(timeIntervalSince1970: 1_000_000)
		let dive = Dive(date: start, durationSeconds: 3600)
		#expect(dive.endDate == start.addingTimeInterval(3600))
	}

	// MARK: - surfaceIntervalFormatted (stored value, no context)

	@Test func surfaceIntervalFormattedUsesStoredValue() {
		let dive = Dive()
		dive.surfaceIntervalSeconds = 90 * 60  // 1h 30m
		#expect(dive.surfaceIntervalFormatted == "1h 30m")
	}

	@Test func surfaceIntervalFormattedWithDays() {
		let dive = Dive()
		dive.surfaceIntervalSeconds = 25 * 3600  // 1d 1h 0m
		#expect(dive.surfaceIntervalFormatted == "1d 1h 0m")
	}

	// MARK: - Fallbacks without a model context

	@Test func effectiveSurfaceIntervalIsZeroWithoutContextOrStoredValue() {
		#expect(Dive().effectiveSurfaceIntervalSeconds == 0)
	}

	@Test func cumulativeDiveTimeFallsBackToOwnDurationWithoutContext() {
		#expect(Dive(durationSeconds: 1800).cumulativeDiveTimeSeconds == 1800)
	}
}
