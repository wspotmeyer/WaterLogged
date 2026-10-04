//
//  ImportedDiveMatcherTests.swift
//  WaterLoggedTests
//
//  Created by John Meyer on 9/12/26.
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
import Testing
@testable import WaterLogged

/// Unit tests for recognizing downloaded dives the logbook already holds.
/// The matcher takes plain dates, so none of these need a SwiftData stack.
@Suite(.tags(.diveComputerDuplicates))
struct ImportedDiveMatcherTests {

	// MARK: - Fixtures

	private let reference = Date(timeIntervalSinceReferenceDate: 800_000_000)

	private func dive(at date: Date) -> ParsedDiveData {
		.fixture(dateTime: date, computerModel: "Oceanic Pro Plus X")
	}

	// MARK: - Matching

	@Test("An exact date match counts as already imported")
	func exactMatch() {
		#expect(ImportedDiveMatcher.isAlreadyImported(
			date: reference,
			sortedExistingDates: [reference]
		))
	}

	@Test("Times inside the tolerance are the same dive")
	func withinTolerance() {
		for offset in [-120.0, -61.0, -1.0, 1.0, 61.0, 120.0] {
			#expect(ImportedDiveMatcher.isAlreadyImported(
				date: reference.addingTimeInterval(offset),
				sortedExistingDates: [reference]
			), "offset \(offset) should match")
		}
	}

	@Test("Times outside the tolerance are different dives")
	func outsideTolerance() {
		for offset in [-3_600.0, -121.0, 121.0, 3_600.0] {
			#expect(!ImportedDiveMatcher.isAlreadyImported(
				date: reference.addingTimeInterval(offset),
				sortedExistingDates: [reference]
			), "offset \(offset) should not match")
		}
	}

	@Test("An empty logbook matches nothing")
	func emptyLogbook() {
		#expect(!ImportedDiveMatcher.isAlreadyImported(
			date: reference,
			sortedExistingDates: []
		))
	}

	@Test("The nearest neighbour is found on either side of the insertion point")
	func findsNeighbourOnEitherSide() {
		let dates = [
			reference.addingTimeInterval(-86_400),
			reference,
			reference.addingTimeInterval(86_400)
		]

		// Just before an existing date, and just after one.
		#expect(ImportedDiveMatcher.isAlreadyImported(
			date: reference.addingTimeInterval(-30),
			sortedExistingDates: dates
		))
		#expect(ImportedDiveMatcher.isAlreadyImported(
			date: reference.addingTimeInterval(30),
			sortedExistingDates: dates
		))
		// Squarely between two existing dives.
		#expect(!ImportedDiveMatcher.isAlreadyImported(
			date: reference.addingTimeInterval(43_200),
			sortedExistingDates: dates
		))
	}

	// MARK: - Filtering

	@Test("A logbook holding every downloaded dive leaves nothing to import")
	func allDivesAlreadyPresent() {
		let dates = (0..<5).map { reference.addingTimeInterval(Double($0) * 86_400) }
		let downloaded = dates.map(dive(at:))

		let result = ImportedDiveMatcher.newDives(from: downloaded, existingDates: dates)
		#expect(result.isEmpty)
	}

	@Test("Only the dives missing from the logbook come back, in download order")
	func keepsOnlyMissingDives() {
		let dates = (0..<5).map { reference.addingTimeInterval(Double($0) * 86_400) }
		let downloaded = dates.map(dive(at:))
		// The logbook has dives 0, 1 and 3 — from UDDF, say.
		let existing = [dates[0], dates[1], dates[3]]

		let result = ImportedDiveMatcher.newDives(from: downloaded, existingDates: existing)
		#expect(result.map(\.dateTime) == [dates[2], dates[4]])
	}

	@Test("A logbook built from UDDF still suppresses the whole download")
	func uddfSourcedLogbookIsRecognized() {
		// UDDF records whole minutes; the computer reports the same dives.
		let uddfDates = (0..<4).map { reference.addingTimeInterval(Double($0) * 7_200) }
		let downloaded = uddfDates
			.map { $0.addingTimeInterval(37) }
			.map(dive(at:))

		let result = ImportedDiveMatcher.newDives(from: downloaded, existingDates: uddfDates)
		#expect(result.isEmpty)
	}

	@Test("An empty logbook keeps every downloaded dive")
	func emptyLogbookKeepsEverything() {
		let downloaded = (0..<3).map {
			dive(at: reference.addingTimeInterval(Double($0) * 86_400))
		}

		let result = ImportedDiveMatcher.newDives(from: downloaded, existingDates: [])
		#expect(result.count == 3)
	}

	@Test("Unsorted logbook dates are handled")
	func unsortedExistingDates() {
		let dates = (0..<5).map { reference.addingTimeInterval(Double($0) * 86_400) }
		let downloaded = dates.map(dive(at:))
		let shuffled = [dates[3], dates[0], dates[4], dates[1]]

		let result = ImportedDiveMatcher.newDives(from: downloaded, existingDates: shuffled)
		#expect(result.map(\.dateTime) == [dates[2]])
	}
}
