//
//  DepthSample+GroupedByDive.swift
//  WaterLogged
//
//  Created by John Meyer on 10/4/26.
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

import SwiftData

extension DepthSample {
	/// Every depth sample in `context`, grouped by the persistent ID of its dive.
	///
	/// SwiftData relationship faulting workaround: when samples are reached through
	/// `dive.diveProfile`, their optional properties (ppo2Bar, cnsPercent,
	/// decoType, tankPressureBar, decoTTSSeconds, etc.) can read as nil even though
	/// values are stored. Fetching the samples directly and grouping them by dive
	/// avoids that lazy-loading path and preserves the data. The UDDF export and
	/// the backup both depend on this.
	static func groupedByDive(in context: ModelContext) throws -> [PersistentIdentifier: [DepthSample]] {
		var samplesByDive: [PersistentIdentifier: [DepthSample]] = [:]
		for sample in try context.fetch(FetchDescriptor<DepthSample>()) {
			if let dive = sample.dive {
				samplesByDive[dive.persistentModelID, default: []].append(sample)
			}
		}
		return samplesByDive
	}
}
