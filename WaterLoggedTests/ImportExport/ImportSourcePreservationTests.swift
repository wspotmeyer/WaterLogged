//
//  ImportSourcePreservationTests.swift
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
import SwiftData
import Testing
@testable import WaterLogged

/// Whether a dive's `importSource` survives the paths that rewrite dives.
///
/// The existing round-trip fixtures all seed `importSource: "UDDF"`, which is
/// also what `UDDFImporter` stamps on every dive it creates — so a path that
/// flattens the value looks identical to one that preserves it. These tests use
/// a dive computer's model name so the difference is visible.
@MainActor
@Suite(.tags(.importExport, .roundTrip))
struct ImportSourcePreservationTests {

	private let computerModel = "Oceanic Pro Plus X"

	@Test("A dive computer import records the computer model as the source")
	func diveComputerImportRecordsModel() throws {
		let container = try TestModelContainer.make()
		let context = container.mainContext

		let parsed = ParsedDiveData(
			dateTime: .now,
			durationSeconds: 2_400,
			maxDepthMeters: 18,
			avgDepthMeters: 12,
			waterTempCelsius: 24,
			samples: [
				ParsedSampleData(elapsedSeconds: 0, depthMeters: 5, tankPressureBar: 200)
			],
			gasMixes: [ParsedGasMixData(oxygenPercent: 21, heliumPercent: 0, name: "Air")],
			diveNumber: nil,
			computerModel: computerModel,
			serialNumber: nil
		)

		try DiveComputerImporter.importDives([parsed], into: context)

		let dive = try #require(try context.fetch(FetchDescriptor<Dive>()).first)
		#expect(dive.importSource == computerModel)
	}

	@Test("Backup and restore preserve a dive computer source")
	func backupRestorePreservesSource() throws {
		let sourceContainer = try TestModelContainer.make()
		let sourceContext = sourceContainer.mainContext
		let dive = Dive(
			diveNumber: 561,
			maxDepthMeters: 18,
			durationSeconds: 2_400,
			importSource: computerModel
		)
		sourceContext.insert(dive)
		let diveId = dive.externalId
		try sourceContext.save()

		try withTemporaryDirectory { scratch in
			let zipURL = try BackupPackager.createExportArchive(
				from: sourceContext, workingDirectory: scratch
			)

			let destContainer = try TestModelContainer.make()
			let destContext = destContainer.mainContext
			try RestorePackager.restoreArchive(
				at: zipURL, into: destContext, workingDirectory: scratch
			)

			let restored = try #require(
				try destContext.fetch(FetchDescriptor<Dive>())
					.first { $0.externalId == diveId }
			)
			#expect(restored.importSource == computerModel)
		}
	}

	@Test("A UDDF round trip cannot carry the original source")
	func uddfRoundTripLosesSource() throws {
		let sourceContainer = try TestModelContainer.make()
		let sourceContext = sourceContainer.mainContext
		let dive = Dive(
			diveNumber: 561,
			maxDepthMeters: 18,
			durationSeconds: 2_400,
			importSource: computerModel
		)
		sourceContext.insert(dive)
		try sourceContext.save()

		let xml = try UDDFExporter.exportString(from: sourceContext)

		let destContainer = try TestModelContainer.make()
		let destContext = destContainer.mainContext
		try UDDFImporter.importData(Data(xml.utf8), into: destContext)

		let restored = try #require(try destContext.fetch(FetchDescriptor<Dive>()).first)
		// UDDF has no element for this, so the file can only say it came from UDDF.
		// Documented here so the behaviour is a decision rather than a surprise:
		// use a backup archive, not a UDDF file, to move dives without losing it.
		#expect(restored.importSource == "UDDF")
	}
}
