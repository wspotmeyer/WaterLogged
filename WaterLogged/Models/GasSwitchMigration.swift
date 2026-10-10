//
//  GasSwitchMigration.swift
//  WaterLogged
//
//  Created by John Meyer on 10/10/26.
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

/// One-time conversion of the legacy `DepthSample.activeGasMixIndex` into the
/// `activeGasMix` relationship.
///
/// The legacy index pointed into a list that was never saved (a dive
/// computer's gas slots, or a UDDF file's mix order), so it can only be
/// resolved when the answer doesn't depend on the list: a dive whose tanks
/// hold exactly one distinct gas mix. Switches on any other dive are dropped;
/// the dive's tanks and mixes are untouched.
///
/// Temporary: delete this type, its launch call, and
/// `DepthSample.activeGasMixIndex` once every device has run it, before the
/// CloudKit schema is deployed to Production.
enum GasSwitchMigration {

	/// Converts every sample still carrying a legacy index and clears the
	/// index, returning how many samples were linked to a gas mix. Clearing
	/// makes later runs a cheap no-op. Saves when anything changed.
	@discardableResult
	static func convertLegacyIndices(in context: ModelContext) throws -> Int {
		let descriptor = FetchDescriptor<DepthSample>(
			predicate: #Predicate<DepthSample> { $0.activeGasMixIndex != nil }
		)
		let samples = try context.fetch(descriptor)
		guard !samples.isEmpty else { return 0 }

		// The single gas mix each dive's tanks hold, or nil when it's ambiguous.
		var mixByDive: [PersistentIdentifier: GasMix?] = [:]
		var converted = 0

		for sample in samples {
			if sample.activeGasMix == nil, let dive = sample.dive {
				let mix: GasMix?
				if let cached = mixByDive[dive.persistentModelID] {
					mix = cached
				} else {
					mix = singleGasMix(of: dive)
					mixByDive[dive.persistentModelID] = mix
				}
				if let mix {
					sample.activeGasMix = mix
					converted += 1
				}
			}
			sample.activeGasMixIndex = nil
		}

		try context.save()
		return converted
	}

	/// The dive's gas mix when all of its tanks hold the same one; otherwise nil.
	private static func singleGasMix(of dive: Dive) -> GasMix? {
		let mixes = (dive.tanks ?? []).compactMap(\.gasMix)
		guard let first = mixes.first,
			  mixes.allSatisfy({ $0.persistentModelID == first.persistentModelID })
		else { return nil }
		return first
	}
}
