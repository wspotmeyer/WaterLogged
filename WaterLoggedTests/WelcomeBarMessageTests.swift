//
//  WelcomeBarMessageTests.swift
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

/// The home screen's empty-logbook message adapts to whether iCloud sync is on.
@MainActor
@Suite
struct WelcomeBarMessageTests {

	@Test func suggestsTurningOnSyncWhenOff() {
		let message = WelcomeBar.message(isCloudSyncActive: false)
		#expect(message.contains("turn on iCloud sync"))
	}

	@Test func explainsPendingSyncInsteadOfSuggestingItWhenOn() {
		let message = WelcomeBar.message(isCloudSyncActive: true)
		#expect(message.contains("once iCloud finishes syncing"))
		#expect(!message.contains("turn on iCloud sync"))
	}
}
