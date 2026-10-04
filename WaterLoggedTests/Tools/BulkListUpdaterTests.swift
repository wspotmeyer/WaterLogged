//
//  BulkListUpdaterTests.swift
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
@testable import WaterLogged

/// Unit tests for the bulk updater's per-item list merge logic, covering the
/// Ignore / Add / Delete paradigm that `BulkUpdateView` uses for equipment and
/// buddies. These exercise `BulkListUpdater.apply` directly with a lightweight
/// stub, so they need no SwiftData stack and run fast and deterministically.
@Suite(.tags(.bulkUpdate))
struct BulkListUpdaterTests {

	/// A minimal stand-in for an `Equipment` or `Buddy`: anything `Identifiable`
	/// works, so the tests don't depend on the SwiftData models.
	private struct Item: Identifiable, Equatable {
		let id: Int
		let name: String
	}

	private let mask = Item(id: 1, name: "Mask")
	private let fins = Item(id: 2, name: "Fins")
	private let torch = Item(id: 3, name: "Torch")
	private let regulator = Item(id: 4, name: "Regulator")

	/// The universe of items the user could pick an action for.
	private var candidates: [Item] { [mask, fins, torch, regulator] }

	// MARK: - Ignore

	@Test("Items with no chosen action leave the list untouched")
	func emptyActionsLeaveListUnchanged() {
		let existing = [mask, fins]
		let result = BulkListUpdater.apply(to: existing, from: candidates, actions: [:])
		#expect(result == existing)
	}

	@Test("Explicit .ignore actions leave the list untouched")
	func explicitIgnoreLeavesListUnchanged() {
		let existing = [mask, fins]
		let actions: [Int: ItemUpdateAction] = [mask.id: .ignore, torch.id: .ignore]
		let result = BulkListUpdater.apply(to: existing, from: candidates, actions: actions)
		#expect(result == existing)
	}

	// MARK: - Add

	@Test("Adding a missing item appends it")
	func addAppendsMissingItem() {
		let result = BulkListUpdater.apply(to: [mask], from: candidates, actions: [torch.id: .add])
		#expect(result == [mask, torch])
	}

	@Test("Adding into an empty list yields just the added items")
	func addToEmptyList() {
		let actions: [Int: ItemUpdateAction] = [mask.id: .add, torch.id: .add]
		let result = BulkListUpdater.apply(to: [], from: candidates, actions: actions)
		#expect(result == [mask, torch])
	}

	@Test("Adding an item already present is a no-op (no duplicate)", .tags(.edgeCase))
	func addExistingItemDoesNotDuplicate() {
		let existing = [mask, fins]
		let result = BulkListUpdater.apply(to: existing, from: candidates, actions: [mask.id: .add])
		#expect(result == existing)
	}

	// MARK: - Delete

	@Test("Deleting a present item removes it")
	func deleteRemovesPresentItem() {
		let existing = [mask, fins, torch]
		let result = BulkListUpdater.apply(to: existing, from: candidates, actions: [fins.id: .delete])
		#expect(result == [mask, torch])
	}

	@Test("Deleting an item that isn't in the list is a no-op", .tags(.edgeCase))
	func deleteAbsentItemDoesNothing() {
		let existing = [mask, fins]
		let result = BulkListUpdater.apply(to: existing, from: candidates, actions: [torch.id: .delete])
		#expect(result == existing)
	}

	// MARK: - Combined

	@Test("Add and delete apply together in one pass")
	func addAndDeleteTogether() {
		let existing = [mask, fins]
		let actions: [Int: ItemUpdateAction] = [fins.id: .delete, torch.id: .add]
		let result = BulkListUpdater.apply(to: existing, from: candidates, actions: actions)
		#expect(result == [mask, torch])
	}

	@Test("Retained items keep their order; additions follow in candidate order")
	func orderIsPreserved() {
		let existing = [torch, mask]
		let actions: [Int: ItemUpdateAction] = [fins.id: .add, regulator.id: .add]
		let result = BulkListUpdater.apply(to: existing, from: candidates, actions: actions)
		#expect(result == [torch, mask, fins, regulator])
	}

	// MARK: - Items outside the candidate set

	@Test("An existing item that isn't a candidate (e.g. retired) is left in place", .tags(.edgeCase))
	func nonCandidateItemIsUntouched() {
		let retired = Item(id: 99, name: "Retired Wing")
		let existing = [mask, retired]
		// `retired` is not among `candidates`, so no action can target it.
		let result = BulkListUpdater.apply(to: existing, from: candidates, actions: [torch.id: .add])
		#expect(result == [mask, retired, torch])
	}
}
