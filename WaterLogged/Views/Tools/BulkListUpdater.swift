//
//  BulkListUpdater.swift
//  WaterLogged
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

/// Pure list-merge logic for the bulk updater's per-item `ItemUpdateAction`
/// choices (Ignore / Add / Delete), extracted from `BulkUpdateView` so it can
/// be unit-tested independently of SwiftUI and SwiftData.
enum BulkListUpdater {
	/// Applies the chosen per-item actions to a dive's existing list, returning
	/// the new list. Order of retained and added items is preserved.
	///
	/// - Items whose action is `.add` are appended if not already present;
	///   adding an item that is already in the list is a no-op (no duplicate).
	/// - Items whose action is `.delete` are removed if present; deleting an
	///   item that isn't in the list is a no-op.
	/// - Items whose action is `.ignore` (or that have no entry in `actions`)
	///   are left untouched.
	///
	/// - Parameters:
	///   - existing: The list currently attached to the dive.
	///   - candidates: All items the user could choose an action for.
	///   - actions: The action chosen for each candidate, keyed by its ID.
	/// - Returns: The updated list to store back on the dive.
	static func apply<Item: Identifiable>(
		to existing: [Item],
		from candidates: [Item],
		actions: [Item.ID: ItemUpdateAction]
	) -> [Item] {
		let toDelete = Set(candidates.filter { actions[$0.id] == .delete }.map(\.id))
		let toAdd = candidates.filter { actions[$0.id] == .add }

		var result = existing.filter { !toDelete.contains($0.id) }
		let present = Set(result.map(\.id))
		result += toAdd.filter { !present.contains($0.id) }
		return result
	}
}
