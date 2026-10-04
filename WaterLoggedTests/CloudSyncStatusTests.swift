//
//  CloudSyncStatusTests.swift
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

/// How the Settings screen describes iCloud sync, given the live preference
/// and the sync mode the container launched with.
@Suite
struct CloudSyncStatusTests {

	@Test func offWhenDisabledSinceLaunch() {
		let status = CloudSyncStatus(isEnabled: false, launchedEnabled: false, isActive: false)
		#expect(status == .off)
	}

	@Test func syncingWhenEnabledAndActive() {
		let status = CloudSyncStatus(isEnabled: true, launchedEnabled: true, isActive: true)
		#expect(status == .syncing)
	}

	@Test func unavailableWhenEnabledButCloudKitFailed() {
		let status = CloudSyncStatus(isEnabled: true, launchedEnabled: true, isActive: false)
		#expect(status == .unavailable)
	}

	@Test(arguments: [true, false])
	func pendingRelaunchWhenPreferenceChangedSinceLaunch(isEnabled: Bool) {
		let status = CloudSyncStatus(isEnabled: isEnabled, launchedEnabled: !isEnabled, isActive: !isEnabled)
		#expect(status == .pendingRelaunch(turningOn: isEnabled))
	}
}
