//
//  ImportedDiveMatcher.swift
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

/// Decides which dives downloaded from a dive computer are not yet in the log book.
///
/// This matches against the dives the log book actually holds rather than against a
/// stored "last import" date. A date watermark only knows about previous dive
/// computer imports, so a log book built from UDDF files or hand-entered dives looks
/// empty to it and the computer's whole log gets offered again.
///
/// Dives are matched on start time. A dive computer records minutes while other
/// sources may record seconds, and a computer's clock can drift from whatever wrote
/// the original entry, so times within `dateTolerance` count as the same dive. Two
/// distinct dives can't begin that close together, and being slightly too eager to
/// offer a dive is far better than silently hiding one.
enum ImportedDiveMatcher {

	/// Start times this close together describe the same dive.
	static let dateTolerance: TimeInterval = 120

	/// The subset of `parsedDives` whose start times don't match a dive already
	/// in the log book, in the order they were downloaded.
	static func newDives(
		from parsedDives: [ParsedDiveData],
		existingDates: [Date]
	) -> [ParsedDiveData] {
		guard !existingDates.isEmpty else { return parsedDives }

		let sorted = existingDates.sorted()
		return parsedDives.filter {
			!isAlreadyImported(date: $0.dateTime, sortedExistingDates: sorted)
		}
	}

	/// Whether a dive starting at `date` is already in the log book.
	/// `sortedExistingDates` must be in ascending order.
	static func isAlreadyImported(
		date: Date,
		sortedExistingDates sorted: [Date]
	) -> Bool {
		// Binary search for the first existing date at or after the target, then
		// check only the neighbours on either side of that insertion point.
		var low = sorted.startIndex
		var high = sorted.endIndex
		while low < high {
			let middle = low + (high - low) / 2
			if sorted[middle] < date {
				low = middle + 1
			} else {
				high = middle
			}
		}

		for index in [low - 1, low] where sorted.indices.contains(index) {
			if abs(sorted[index].timeIntervalSince(date)) <= dateTolerance {
				return true
			}
		}
		return false
	}
}
