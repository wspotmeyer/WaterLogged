//
//  UDDFParserTests.swift
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

/// Parser-level tests that feed UDDF XML strings straight into
/// `UDDFImporter.parse(xml:)` and assert on the intermediate representation,
/// with no SwiftData involvement. Fast and side-effect free.
@Suite(.tags(.importExport))
struct UDDFParserTests {

	// MARK: - Structure

	@Test func minimalDiveParsesCoreFields() throws {
		let result = try UDDFImporter.parse(xml: UDDFFixtures.minimalDive)
		try #require(result.dives.count == 1)
		let dive = result.dives[0]
		#expect(dive.id == "dive-1")
		#expect(dive.diveNumber == 42)
		#expect(dive.greatestDepth == 18.5)
		#expect(dive.diveDuration == 2400)
		#expect(dive.dateTime != nil)
	}

	@Test func richDiveParsesAllSections() throws {
		let result = try UDDFImporter.parse(xml: UDDFFixtures.richDive)

		#expect(result.gases["mix-1"]?.name == "EAN32")
		#expect(result.sites["site-1"]?.name == "Palancar Reef")
		#expect(result.sites["site-1"]?.country == "Mexico")
		#expect(result.buddies["buddy-1"]?.firstName == "Alex")
		#expect(result.owner?.firstName == "Jane")

		let dive = try #require(result.dives.first)
		#expect(dive.siteRef == "site-1")
		#expect(dive.buddyRefs.contains("buddy-1"))
		#expect(dive.tanks.count == 1)
		#expect(dive.waypoints.count == 2)
		#expect(dive.rating == 5)
		#expect(dive.visibilityMeters == 25)
	}

	@Test func tankPressuresConvertPascalsToBar() throws {
		let result = try UDDFImporter.parse(xml: UDDFFixtures.richDive)
		let tank = try #require(result.dives.first?.tanks.first)
		// 20,000,000 Pa / 100,000 = 200 bar; 6,000,000 Pa = 60 bar.
		#expect(tank.startPressureBar == 200)
		#expect(tank.endPressureBar == 60)
		#expect(tank.mixRef == "mix-1")
	}

	@Test func waypointMeasuredPO2AndNoDecoParsed() throws {
		let result = try UDDFImporter.parse(xml: UDDFFixtures.richDive)
		let deepWaypoint = try #require(result.dives.first?.waypoints.last)
		#expect(deepWaypoint.depth == 18.5)
		// 42,000 Pa / 100,000 = 0.42 bar.
		#expect(deepWaypoint.ppo2Bar == 0.42)
		#expect(deepWaypoint.nodecoTimeSeconds == 1200)
	}

	// MARK: - Gas fraction resolution

	@Test func explicitNitrogenFractionIsPreserved() throws {
		let result = try UDDFImporter.parse(xml: UDDFFixtures.gasExplicitNitrogen)
		let gas = try #require(result.gases["mix-1"])
		#expect(gas.n2Fraction == 0.60)
		#expect(gas.resolvedN2Fraction == 0.60)
	}

	@Test func computedNitrogenFractionFromRemainder() throws {
		let result = try UDDFImporter.parse(xml: UDDFFixtures.gasComputedNitrogen)
		let gas = try #require(result.gases["mix-1"])
		#expect(gas.n2Fraction == nil)
		// 1.0 - 0.21 O2 - 0.35 He = 0.44 N2.
		#expect(abs(gas.resolvedN2Fraction - 0.44) < 0.0001)
	}

	// MARK: - Temperature Kelvin/Celsius heuristic

	@Test("Kelvin values above the 200 threshold convert to Celsius", arguments: [
		(raw: "293.15", celsius: 20.0),
		(raw: "300.15", celsius: 27.0),
		(raw: "273.15", celsius: 0.0)
	])
	func kelvinConvertsToCelsius(raw: String, celsius: Double) throws {
		let result = try UDDFImporter.parse(xml: UDDFFixtures.waypointTemperature(raw))
		let temp = try #require(result.dives.first?.waypoints.first?.temperatureCelsius)
		#expect(abs(temp - celsius) < 0.0001)
	}

	@Test("Values below 200 are treated as already-Celsius", arguments: ["20", "25.5", "199"])
	func lowValuesTreatedAsCelsius(raw: String) throws {
		let result = try UDDFImporter.parse(xml: UDDFFixtures.waypointTemperature(raw))
		let temp = try #require(result.dives.first?.waypoints.first?.temperatureCelsius)
		#expect(abs(temp - (Double(raw) ?? -1)) < 0.0001)
	}

	// MARK: - Bare ampersand escaping

	@Test(.tags(.edgeCase)) func bareAmpersandInNotesParses() throws {
		let result = try UDDFImporter.parse(xml: UDDFFixtures.bareAmpersandNote)
		let notes = try #require(result.dives.first?.notes)
		#expect(notes.localizedStandardContains("M&S"))
		#expect(notes.localizedStandardContains("Nitrox & fun"))
	}
}
