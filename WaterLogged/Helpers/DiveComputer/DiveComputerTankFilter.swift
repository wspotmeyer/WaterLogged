//
//  DiveComputerTankFilter.swift
//  WaterLogged
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

/// Decides which of a dive computer's reported gas mixes should become a `Tank`.
///
/// Most dive computers report every gas mix *slot* they can be configured with
/// rather than the gases actually breathed on the dive. Oceanic models, for
/// example, hard-code a slot count per model (3, 4, or 6) and report an unset
/// slot as plain air, so a single-tank dive arrives with three or five phantom
/// "Air" mixes alongside the real one. Creating a `Tank` per reported mix fills
/// the dive with empty tanks the diver never used.
///
/// A slot is treated as a real tank when either:
///
/// - it has tank pressure data in the depth profile, or
/// - a sample says the diver actually breathed from it (a gas switch).
///
/// If nothing qualifies — the common case for a computer without an air
/// integration transmitter — the first slot is kept so the dive still records
/// one tank with its gas mix.
enum DiveComputerTankFilter {

	/// Indices into `parsed.gasMixes` that should each become a `Tank`,
	/// in ascending order.
	static func tankGasMixIndices(for parsed: ParsedDiveData) -> [Int] {
		let mixIndices = parsed.gasMixes.indices
		guard !mixIndices.isEmpty else { return [] }

		var keep = Set<Int>()

		// Keep any slot whose pressure channel carries data. libdivecomputer only
		// exposes two pressure channels, which map to gas mix slots 0 and 1.
		if parsed.samples.contains(where: { $0.tankPressureBar != nil }) {
			keep.insert(0)
		}
		if parsed.samples.contains(where: { $0.tank2PressureBar != nil }),
		   mixIndices.contains(1) {
			keep.insert(1)
		}

		// Keep any slot the diver switched to during the dive, even without a
		// transmitter — a deco or stage gas is a real tank.
		for sample in parsed.samples {
			if let active = sample.activeGasMixIndex, mixIndices.contains(active) {
				keep.insert(active)
			}
		}

		// Nothing identified a tank, so fall back to the first reported mix.
		if keep.isEmpty {
			keep.insert(mixIndices.lowerBound)
		}

		return keep.sorted()
	}

	/// The start and end pressures (bar) for the given gas mix slot, read from
	/// the depth profile. Slots beyond the two libdivecomputer pressure channels
	/// have no pressure data.
	static func pressures(
		forGasMixIndex index: Int,
		in parsed: ParsedDiveData
	) -> (start: Double?, end: Double?) {
		switch index {
			case 0:
				return (
					parsed.samples.first(where: { $0.tankPressureBar != nil })?.tankPressureBar,
					parsed.samples.last(where: { $0.tankPressureBar != nil })?.tankPressureBar
				)
			case 1:
				return (
					parsed.samples.first(where: { $0.tank2PressureBar != nil })?.tank2PressureBar,
					parsed.samples.last(where: { $0.tank2PressureBar != nil })?.tank2PressureBar
				)
			default:
				return (nil, nil)
		}
	}
}
