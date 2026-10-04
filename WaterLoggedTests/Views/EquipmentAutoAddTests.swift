//
//  EquipmentAutoAddTests.swift
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

import Testing
import SwiftData
@testable import WaterLogged

/// Unit tests for the equipment the dive form ticks by itself when logging a new dive.
/// `shouldPreselect` takes plain `Bool` flags, so only the `preselection(from:)` cases
/// need a SwiftData stack.
@Suite(.tags(.autoAddEquipment))
struct EquipmentAutoAddTests {

	// MARK: - The flag

	@Test(
		"Only gear that is flagged and still in service is preselected",
		arguments: [
			(autoAdd: true, retired: false, expected: true),
			(autoAdd: true, retired: true, expected: false),
			(autoAdd: false, retired: false, expected: false),
			(autoAdd: false, retired: true, expected: false)
		]
	)
	func flagTruthTable(autoAdd: Bool, retired: Bool, expected: Bool) {
		#expect(EquipmentAutoAdd.shouldPreselect(autoAddToDives: autoAdd, isRetired: retired) == expected)
	}

	// MARK: - Building the selection

	@MainActor
	@Test("The preselection is exactly the flagged, unretired equipment")
	func preselectionPicksFlaggedGear() throws {
		// Hold the container: a ModelContext does not retain the container that made it.
		let container = try TestModelContainer.make()
		let context = container.mainContext

		let mask = Equipment(name: "Mask", type: .mask, autoAddToDives: true)
		let computer = Equipment(name: "Computer", type: .diveComputer, autoAddToDives: true)
		let camera = Equipment(name: "Camera", type: .camera)
		let oldFins = Equipment(name: "Old Fins", type: .fins, isRetired: true, autoAddToDives: true)
		let all = [mask, computer, camera, oldFins]
		for item in all {
			context.insert(item)
		}

		let selection = EquipmentAutoAdd.preselection(from: all)
		#expect(selection == Set([mask, computer].map(\.persistentModelID)))
		#expect(!selection.contains(camera.persistentModelID))
		#expect(!selection.contains(oldFins.persistentModelID))
	}

	@MainActor
	@Test("Nothing is preselected when no equipment carries the flag")
	func preselectionIsEmptyWithoutFlaggedGear() throws {
		let container = try TestModelContainer.make()
		let context = container.mainContext

		let all = [
			Equipment(name: "Camera", type: .camera),
			Equipment(name: "Knife", type: .knife)
		]
		for item in all {
			context.insert(item)
		}

		#expect(EquipmentAutoAdd.preselection(from: all).isEmpty)
		#expect(EquipmentAutoAdd.preselection(from: []).isEmpty)
	}
}
