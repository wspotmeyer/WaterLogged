//
//  EquipmentAutoAdd.swift
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
import SwiftData

/// Decides which equipment a newly logged dive starts out with.
///
/// `Equipment.autoAddToDives` marks the gear a diver brings on every dive — mask, computer, BCD — so
/// the dive form can tick those rows itself rather than making them do it by hand each time. The
/// result is only a starting point: the form's toggles stay editable, so anything preselected can be
/// turned off before saving, and nothing is written to the dive until it is saved.
enum EquipmentAutoAdd {

	/// Whether an item flagged for auto-add should still be offered to a new dive.
	///
	/// Retired gear is excluded. The dive form hides retired items from its equipment list, so
	/// preselecting one would attach it to the dive with no visible row to untick — and a retired item
	/// is, by definition, not gear the diver is still taking in the water.
	nonisolated static func shouldPreselect(autoAddToDives: Bool, isRetired: Bool) -> Bool {
		autoAddToDives && !isRetired
	}

	/// The equipment to preselect for a new dive, out of everything in the logbook.
	///
	/// The only member that touches `Equipment`, so the only one that stays on the main actor.
	static func preselection(from equipment: [Equipment]) -> Set<PersistentIdentifier> {
		let preselected = equipment.filter {
			shouldPreselect(autoAddToDives: $0.autoAddToDives, isRetired: $0.isRetired)
		}
		return Set(preselected.map(\.persistentModelID))
	}
}
