//
//  DiveComputerTankFilterTests.swift
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

/// Unit tests for the gas mix slot → tank selection applied to dive computer
/// downloads. `ParsedDiveData` is a plain value type, so none of these need a
/// SwiftData stack.
@Suite(.tags(.diveComputerTanks))
struct DiveComputerTankFilterTests {

	// MARK: - Fixtures

	/// Four configured gas slots, the way an Oceanic reports them — unset slots
	/// come back as plain air rather than being omitted.
	private static let fourAirSlots = [
		ParsedGasMixData(oxygenPercent: 32, heliumPercent: 0, name: "EAN32"),
		ParsedGasMixData(oxygenPercent: 21, heliumPercent: 0, name: "Air"),
		ParsedGasMixData(oxygenPercent: 21, heliumPercent: 0, name: "Air"),
		ParsedGasMixData(oxygenPercent: 21, heliumPercent: 0, name: "Air")
	]

	private func dive(
		gasMixes: [ParsedGasMixData],
		samples: [ParsedSampleData]
	) -> ParsedDiveData {
		ParsedDiveData(
			dateTime: .now,
			durationSeconds: 2_400,
			maxDepthMeters: 18,
			avgDepthMeters: 12,
			waterTempCelsius: 24,
			samples: samples,
			gasMixes: gasMixes,
			diveNumber: nil,
			computerModel: "Oceanic Test",
			serialNumber: nil
		)
	}

	private func sample(
		_ seconds: Int,
		depth: Double = 10,
		pressure: Double? = nil,
		pressure2: Double? = nil,
		activeGasMixIndex: Int? = nil
	) -> ParsedSampleData {
		ParsedSampleData(
			elapsedSeconds: seconds,
			depthMeters: depth,
			tankPressureBar: pressure,
			tank2PressureBar: pressure2,
			activeGasMixIndex: activeGasMixIndex
		)
	}

	// MARK: - Slot selection

	@Test("Four reported slots with pressure on only the first yield one tank")
	func onlySlotWithPressureIsKept() {
		let parsed = dive(
			gasMixes: Self.fourAirSlots,
			samples: [
				sample(0, pressure: 210),
				sample(60, pressure: 190),
				sample(120, pressure: 70)
			]
		)

		#expect(DiveComputerTankFilter.tankGasMixIndices(for: parsed) == [0])
	}

	@Test("Both pressure channels produce two tanks")
	func bothPressureChannelsAreKept() {
		let parsed = dive(
			gasMixes: Self.fourAirSlots,
			samples: [
				sample(0, pressure: 210, pressure2: 200),
				sample(60, pressure: 190, pressure2: 180)
			]
		)

		#expect(DiveComputerTankFilter.tankGasMixIndices(for: parsed) == [0, 1])
	}

	@Test("A gas the diver switched to counts even without a transmitter")
	func gasSwitchWithoutPressureIsKept() {
		let parsed = dive(
			gasMixes: Self.fourAirSlots,
			samples: [
				sample(0, pressure: 210, activeGasMixIndex: 0),
				sample(600, activeGasMixIndex: 2)
			]
		)

		#expect(DiveComputerTankFilter.tankGasMixIndices(for: parsed) == [0, 2])
	}

	@Test("A computer with no pressure data still records one tank")
	func fallsBackToFirstSlotWithoutAnyTankData() {
		let parsed = dive(
			gasMixes: Self.fourAirSlots,
			samples: [sample(0), sample(60), sample(120)]
		)

		#expect(DiveComputerTankFilter.tankGasMixIndices(for: parsed) == [0])
	}

	@Test("A dive with no samples at all still records one tank")
	func fallsBackToFirstSlotWithoutSamples() {
		let parsed = dive(gasMixes: Self.fourAirSlots, samples: [])

		#expect(DiveComputerTankFilter.tankGasMixIndices(for: parsed) == [0])
	}

	@Test("A freedive reporting no gas mixes produces no tanks")
	func noGasMixesProducesNoTanks() {
		let parsed = dive(gasMixes: [], samples: [sample(0, depth: 8)])

		#expect(DiveComputerTankFilter.tankGasMixIndices(for: parsed).isEmpty)
	}

	@Test("A single reported slot is never dropped by the second pressure channel")
	func secondChannelIgnoredWhenOnlyOneSlotExists() {
		let parsed = dive(
			gasMixes: [ParsedGasMixData(oxygenPercent: 21, heliumPercent: 0, name: "Air")],
			samples: [sample(0, pressure: 200, pressure2: 190)]
		)

		#expect(DiveComputerTankFilter.tankGasMixIndices(for: parsed) == [0])
	}

	@Test("An out-of-range active gas mix index is ignored")
	func outOfRangeGasSwitchIsIgnored() {
		let parsed = dive(
			gasMixes: Self.fourAirSlots,
			samples: [
				sample(0, pressure: 200),
				sample(60, activeGasMixIndex: 9),
				sample(120, activeGasMixIndex: -1)
			]
		)

		#expect(DiveComputerTankFilter.tankGasMixIndices(for: parsed) == [0])
	}

	// MARK: - Pressures

	@Test("Start and end pressures come from the first and last samples carrying them")
	func pressuresBracketTheProfile() {
		let parsed = dive(
			gasMixes: Self.fourAirSlots,
			samples: [
				sample(0),
				sample(30, pressure: 205, pressure2: 198),
				sample(60, pressure: 150, pressure2: 120),
				sample(90, pressure: 65, pressure2: 40),
				sample(120)
			]
		)

		let first = DiveComputerTankFilter.pressures(forGasMixIndex: 0, in: parsed)
		#expect(first.start == 205)
		#expect(first.end == 65)

		let second = DiveComputerTankFilter.pressures(forGasMixIndex: 1, in: parsed)
		#expect(second.start == 198)
		#expect(second.end == 40)
	}

	@Test("Slots past the two pressure channels have no pressures")
	func thirdSlotHasNoPressures() {
		let parsed = dive(
			gasMixes: Self.fourAirSlots,
			samples: [sample(0, pressure: 200, pressure2: 190)]
		)

		let third = DiveComputerTankFilter.pressures(forGasMixIndex: 2, in: parsed)
		#expect(third.start == nil)
		#expect(third.end == nil)
	}
}
