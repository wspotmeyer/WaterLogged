//
//  GasSwitchMigrationTests.swift
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

/// The one-time conversion of legacy gas-switch indices, and keeping gas
/// switches intact when duplicate gas mixes are merged.
@MainActor
struct GasSwitchMigrationTests {

	/// A dive with one tank per gas and one sample carrying a legacy index.
	@discardableResult
	private func insertDive(gases: [GasMix], legacyIndex: Int, into context: ModelContext) -> DepthSample {
		let dive = Dive(maxDepthMeters: 20, durationSeconds: 1_800, importSource: "Test")
		context.insert(dive)
		for gas in gases {
			let tank = Tank(gasMix: gas, startPressureBar: 200)
			tank.dive = dive
			context.insert(tank)
		}
		let sample = DepthSample(elapsedSeconds: 0, depthMeters: 5)
		sample.activeGasMixIndex = legacyIndex
		sample.dive = dive
		context.insert(sample)
		return sample
	}

	@Test("A single-gas dive's legacy switch becomes a link to its mix")
	func singleGasDiveConverts() throws {
		let container = try TestModelContainer.make()
		let context = container.mainContext
		let ean32 = GasMix(name: "EAN32", oxygenPercent: 32)
		context.insert(ean32)
		// Two tanks of the same mix still count as one gas.
		let sample = insertDive(gases: [ean32, ean32], legacyIndex: 3, into: context)
		try context.save()

		let converted = try GasSwitchMigration.convertLegacyIndices(in: context)
		#expect(converted == 1)
		#expect(sample.activeGasMix?.persistentModelID == ean32.persistentModelID)
		#expect(sample.activeGasMixIndex == nil)
	}

	@Test("A multi-gas dive's legacy switch is dropped, its tanks kept")
	func multiGasDiveDrops() throws {
		let container = try TestModelContainer.make()
		let context = container.mainContext
		let ean32 = GasMix(name: "EAN32", oxygenPercent: 32)
		let ean50 = GasMix(name: "EAN50", oxygenPercent: 50)
		context.insert(ean32)
		context.insert(ean50)
		let sample = insertDive(gases: [ean32, ean50], legacyIndex: 1, into: context)
		try context.save()

		let converted = try GasSwitchMigration.convertLegacyIndices(in: context)
		#expect(converted == 0)
		#expect(sample.activeGasMix == nil)
		#expect(sample.activeGasMixIndex == nil)
		#expect(sample.dive?.tanks?.count == 2)
	}

	@Test("Running the conversion again changes nothing")
	func secondRunIsNoOp() throws {
		let container = try TestModelContainer.make()
		let context = container.mainContext
		let air = GasMix()
		context.insert(air)
		insertDive(gases: [air], legacyIndex: 0, into: context)
		try context.save()

		#expect(try GasSwitchMigration.convertLegacyIndices(in: context) == 1)
		#expect(try GasSwitchMigration.convertLegacyIndices(in: context) == 0)
		#expect(!context.hasChanges)
	}

	@Test("Merging duplicate gas mixes moves their gas switches to the survivor")
	func mergeDuplicatesRepointsSwitches() throws {
		let container = try TestModelContainer.make()
		let context = container.mainContext
		let survivor = GasMix(externalId: "A", name: "EAN32", oxygenPercent: 32)
		let duplicate = GasMix(externalId: "B", name: "EAN32", oxygenPercent: 32)
		context.insert(survivor)
		context.insert(duplicate)
		let sample = DepthSample(elapsedSeconds: 0, depthMeters: 5, activeGasMix: duplicate)
		context.insert(sample)
		try context.save()

		#expect(try GasMix.mergeDuplicates(in: context) == 1)
		#expect(sample.activeGasMix?.externalId == "A")
	}
}
