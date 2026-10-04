//
//  TestTags.swift
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

/// Cross-cutting tags so the critical data-interchange tests can be filtered
/// and run as a group regardless of which suite they live in.
extension Tag {
	/// UDDF import/export coverage.
	@Tag static var importExport: Self
	/// Backup archive creation and restore coverage.
	@Tag static var backup: Self
	/// Tests that feed deliberately broken input and assert on the thrown error.
	@Tag static var malformedInput: Self
	/// Tests guarding a subtle or historically fragile behavior.
	@Tag static var edgeCase: Self
	/// Export → import (or backup → restore) fidelity checks.
	@Tag static var roundTrip: Self
	/// Bulk updater per-item list logic (equipment / buddies).
	@Tag static var bulkUpdate: Self
	/// The dive list's tag filter vocabulary and matching rules.
	@Tag static var tagFilter: Self
	/// Equipment preselected onto a new dive by the auto-add flag.
	@Tag static var autoAddEquipment: Self
	/// Which of a dive computer's gas mix slots become tanks on import.
	@Tag static var diveComputerTanks: Self
	/// Recognizing downloaded dives the logbook already holds.
	@Tag static var diveComputerDuplicates: Self
}
