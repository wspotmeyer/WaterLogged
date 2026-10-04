//
//  DecoTypeTests.swift
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

/// `DecoType` is the single place that understands how each import source spells
/// a decompression state, so the vocabulary it accepts is worth pinning down —
/// including the spellings written into the store by earlier builds.
@MainActor
@Suite(.tags(.edgeCase))
struct DecoTypeTests {

	// MARK: - Parsing import-source vocabularies

	@Test(arguments: ["ndl", "NDL", "nodeco", "No Deco", "nodecotime"])
	func parsesNoDecoLimitSpellings(_ raw: String) {
		#expect(DecoType(importedValue: raw) == .noDecoLimit)
	}

	@Test(arguments: ["safety", "Safety Stop", "safetystop", "SAFETY_STOP"])
	func parsesSafetyStopSpellings(_ raw: String) {
		#expect(DecoType(importedValue: raw) == .safetyStop)
	}

	/// "mandatory" is UDDF's spelling and "Deco Stop" is libdivecomputer's; both
	/// used to fall through to an unknown state and render as a gray chart dot.
	@Test(arguments: ["deco", "Deco Stop", "decostop", "mandatory", "Decompression Stop"])
	func parsesDecoStopSpellings(_ raw: String) {
		#expect(DecoType(importedValue: raw) == .decoStop)
	}

	@Test(arguments: ["deep", "Deep Stop", "deepstop"])
	func parsesDeepStopSpellings(_ raw: String) {
		#expect(DecoType(importedValue: raw) == .deepStop)
	}

	/// libdivecomputer's "Unknown" — and anything else unrecognized — means the
	/// sample carries no deco information rather than a fabricated state.
	@Test(arguments: ["Unknown", "", "   ", "gradient factor"])
	func rejectsUnrecognizedValues(_ raw: String) {
		#expect(DecoType(importedValue: raw) == nil)
	}

	/// Every case must survive a trip through its own raw value, since that is
	/// what gets persisted.
	@Test func rawValuesRoundTrip() {
		for status in DecoType.allCases {
			#expect(DecoType(importedValue: status.rawValue) == status)
		}
	}

	// MARK: - UDDF mapping

	@Test func uddfKindsMatchTheSchemaVocabulary() {
		#expect(DecoType.safetyStop.uddfDecoStopKind == "safety")
		#expect(DecoType.decoStop.uddfDecoStopKind == "mandatory")
		// UDDF has no deep-stop kind; it is still a required stop.
		#expect(DecoType.deepStop.uddfDecoStopKind == "mandatory")
		// NDL is written as <nodecotime>, never as a <decostop>.
		#expect(DecoType.noDecoLimit.uddfDecoStopKind == nil)
	}

	@Test func onlyNoDecoLimitIsNotAStop() {
		#expect(DecoType.noDecoLimit.isStop == false)
		#expect(DecoType.safetyStop.isStop)
		#expect(DecoType.decoStop.isStop)
		#expect(DecoType.deepStop.isStop)
	}

	// MARK: - Display names

	/// The labels shown in the profile chart's deco-status row.
	@Test func displayNamesAreTheDiverFacingSpellings() {
		#expect(String(localized: DecoType.noDecoLimit.displayName) == "No Deco")
		#expect(String(localized: DecoType.safetyStop.displayName) == "Safety Stop")
		#expect(String(localized: DecoType.decoStop.displayName) == "Deco Stop")
		#expect(String(localized: DecoType.deepStop.displayName) == "Deep Stop")
	}

	/// Every display name is also a spelling the parser accepts, so a label that
	/// ends up in a log or a hand-edited file reads back as the same case.
	@Test func displayNamesParseBackToTheSameCase() {
		for status in DecoType.allCases {
			#expect(DecoType(importedValue: String(localized: status.displayName)) == status)
		}
	}

	// MARK: - DepthSample bridging

	/// The persisted string stays the storage format, so the accessor has to
	/// write canonical raw values and read legacy ones.
	@Test func depthSampleNormalizesOnWriteAndToleratesLegacyValues() {
		let sample = DepthSample(elapsedSeconds: 60, depthMeters: 12, decoStatus: .decoStop)
		#expect(sample.decoType == "deco")
		#expect(sample.decoStatus == .decoStop)

		// A value written by an older build, straight from libdivecomputer.
		sample.decoType = "Deco Stop"
		#expect(sample.decoStatus == .decoStop)

		// A value written by an older build, straight from a UDDF import.
		sample.decoType = "mandatory"
		#expect(sample.decoStatus == .decoStop)

		sample.decoStatus = nil
		#expect(sample.decoType == nil)
	}

	@Test func depthSampleReportsNoStatusForUnrecognizedStoredValue() {
		let sample = DepthSample(elapsedSeconds: 60, depthMeters: 12)
		sample.decoType = "Unknown"
		#expect(sample.decoStatus == nil)
	}
}
