//
//  GasSwitchRoundTripTests.swift
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

/// Gas switches (`DepthSample.activeGasMix`) through every path that writes or
/// reads them: dive computer import, UDDF export/import, and backup/restore.
@MainActor
@Suite(.tags(.importExport, .roundTrip))
struct GasSwitchRoundTripTests {

	/// The two gases the seeded dive switches between: the bottom gas at the
	/// start, the deco gas at 30 minutes, and no switch on other samples.
	private struct Seeded {
		let bottomGas: GasMix
		let decoGas: GasMix
	}

	/// A two-gas dive (EAN32 → Trimix 21/35) in a logbook that also holds
	/// unrelated mixes, so a switch resolved by position rather than identity
	/// lands on the wrong gas.
	private func seedTwoGasDive(into context: ModelContext) throws -> Seeded {
		for (name, o2) in [("Air", 21.0), ("EAN36", 36.0), ("Oxygen", 100.0)] {
			context.insert(GasMix(name: name, oxygenPercent: o2))
		}
		let bottomGas = GasMix(name: "EAN32", oxygenPercent: 32)
		let decoGas = GasMix(name: "Trimix 21/35", oxygenPercent: 21, heliumPercent: 35)
		context.insert(bottomGas)
		context.insert(decoGas)

		let dive = Dive(maxDepthMeters: 40, durationSeconds: 3_000, importSource: "UDDF")
		context.insert(dive)
		for gas in [bottomGas, decoGas] {
			let tank = Tank(gasMix: gas, startPressureBar: 200, endPressureBar: 80)
			tank.dive = dive
			context.insert(tank)
		}

		let switches: [Int: GasMix] = [0: bottomGas, 1_800: decoGas]
		for seconds in stride(from: 0, through: 3_000, by: 600) {
			let sample = DepthSample(elapsedSeconds: seconds, depthMeters: 20, activeGasMix: switches[seconds])
			sample.dive = dive
			context.insert(sample)
		}
		try context.save()
		return Seeded(bottomGas: bottomGas, decoGas: decoGas)
	}

	/// The `externalId` of the gas each sample switched to, keyed by elapsed
	/// seconds, for samples that carry a switch.
	private func switchedGasIds(in context: ModelContext) throws -> [Int: String] {
		let samples = try context.fetch(FetchDescriptor<DepthSample>())
		var result: [Int: String] = [:]
		for sample in samples {
			if let gas = sample.activeGasMix {
				result[sample.elapsedSeconds] = gas.externalId
			}
		}
		return result
	}

	@Test("Gas switches survive UDDF export and import, every time")
	func switchesSurviveUDDFRoundTrip() throws {
		let sourceContainer = try TestModelContainer.make()
		let sourceContext = sourceContainer.mainContext
		let seeded = try seedTwoGasDive(into: sourceContext)
		let expected = [0: seeded.bottomGas.externalId, 1_800: seeded.decoGas.externalId]

		// The old index-based export picked a mix from an unsorted fetch, so it
		// was wrong only some of the time; repeat to catch nondeterminism.
		for _ in 0..<5 {
			let xml = try UDDFExporter.exportString(from: sourceContext)
			let destContainer = try TestModelContainer.make()
			let destContext = destContainer.mainContext
			try UDDFImporter.importData(Data(xml.utf8), into: destContext)
			#expect(try switchedGasIds(in: destContext) == expected)
		}
	}

	@Test("A switch to a mix the file never defined imports as no switch", .tags(.malformedInput))
	func undefinedSwitchMixRefIsIgnored() throws {
		let sourceContainer = try TestModelContainer.make()
		let sourceContext = sourceContainer.mainContext
		let seeded = try seedTwoGasDive(into: sourceContext)
		let decoRef = UDDFIdentifier.xmlID(for: seeded.decoGas.externalId)
		let xml = try UDDFExporter.exportString(from: sourceContext)
			.replacing("<switchmix ref=\"\(decoRef)\"", with: "<switchmix ref=\"undefined-mix\"")

		let destContainer = try TestModelContainer.make()
		let destContext = destContainer.mainContext
		try UDDFImporter.importData(Data(xml.utf8), into: destContext)
		#expect(try switchedGasIds(in: destContext) == [0: seeded.bottomGas.externalId])
	}

	@Test("Exporting without gas mixes writes no dangling switchmix")
	func switchesSkippedWhenGasMixesNotExported() throws {
		let sourceContainer = try TestModelContainer.make()
		let sourceContext = sourceContainer.mainContext
		_ = try seedTwoGasDive(into: sourceContext)
		var selection = UDDFExportSelection.all
		selection.remove(.gasMixes)

		let xml = try UDDFExporter.exportString(from: sourceContext, selecting: selection)
		#expect(!xml.contains("<switchmix"))
	}

	@Test("Gas switches survive backup and restore", .tags(.backup))
	func switchesSurviveBackupAndRestore() throws {
		let sourceContainer = try TestModelContainer.make()
		let sourceContext = sourceContainer.mainContext
		let seeded = try seedTwoGasDive(into: sourceContext)

		try withTemporaryDirectory { scratch in
			let zipURL = try BackupPackager.createExportArchive(from: sourceContext, workingDirectory: scratch)
			let destContainer = try TestModelContainer.make()
			let destContext = destContainer.mainContext
			try RestorePackager.restoreArchive(at: zipURL, into: destContext, workingDirectory: scratch)
			#expect(try switchedGasIds(in: destContext) == [
				0: seeded.bottomGas.externalId,
				1_800: seeded.decoGas.externalId
			])
		}
	}

	@Test("Dive computer switches resolve through the computer's gas slots", .tags(.diveComputerTanks))
	func diveComputerSwitchesResolveBySlot() throws {
		let container = try TestModelContainer.make()
		let context = container.mainContext
		// Slot 0 is an unset phantom slot; the diver breathed slots 1 and 2.
		let parsed = ParsedDiveData.fixture(
			samples: [
				ParsedSampleData(elapsedSeconds: 0, depthMeters: 5, activeGasMixIndex: 1),
				ParsedSampleData(elapsedSeconds: 600, depthMeters: 40),
				ParsedSampleData(elapsedSeconds: 1_800, depthMeters: 21, activeGasMixIndex: 2),
				ParsedSampleData(elapsedSeconds: 2_400, depthMeters: 9, activeGasMixIndex: 7)
			],
			gasMixes: [
				ParsedGasMixData(oxygenPercent: 21, heliumPercent: 0, name: "Air"),
				ParsedGasMixData(oxygenPercent: 32, heliumPercent: 0, name: "EAN32"),
				ParsedGasMixData(oxygenPercent: 50, heliumPercent: 0, name: "EAN50")
			]
		)
		try DiveComputerImporter.importDives([parsed], into: context)

		let samples = try context.fetch(FetchDescriptor<DepthSample>(sortBy: [SortDescriptor(\.elapsedSeconds)]))
		#expect(samples.map { $0.activeGasMix?.name } == ["EAN32", nil, "EAN50", nil])
		#expect(samples.allSatisfy { $0.activeGasMixIndex == nil })
	}
}
