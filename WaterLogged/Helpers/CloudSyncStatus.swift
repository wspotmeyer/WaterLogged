//
//  CloudSyncStatus.swift
//  WaterLogged
//
//  Created by John Meyer on 10/3/26.
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

/// What the Settings screen tells the user about iCloud sync.
///
/// The model container picks its sync mode once, at launch (see `WaterLoggedStore`),
/// so the live preference and the running container can disagree until the next launch.
enum CloudSyncStatus: Equatable {
	/// Sync is on and the container is syncing through CloudKit.
	case syncing
	/// Sync is off; the logbook lives on this device only.
	case off
	/// Sync was requested at launch, but CloudKit couldn't be set up.
	case unavailable
	/// The preference changed since launch; a relaunch applies it.
	case pendingRelaunch(turningOn: Bool)

	/// - Parameters:
	///   - isEnabled: The current value of the user's preference.
	///   - launchedEnabled: The preference's value when the container was created.
	///   - isActive: Whether the container is actually syncing through CloudKit.
	init(isEnabled: Bool, launchedEnabled: Bool, isActive: Bool) {
		if isEnabled != launchedEnabled {
			self = .pendingRelaunch(turningOn: isEnabled)
		} else if !isEnabled {
			self = .off
		} else if isActive {
			self = .syncing
		} else {
			self = .unavailable
		}
	}

	/// Explanatory text for the Settings footer.
	var message: String {
		switch self {
			case .syncing:
				"Your logbook syncs with other devices signed in to the same iCloud account."
			case .off:
				"Your logbook is stored on this device only."
			case .unavailable:
				"iCloud sync couldn’t start. Make sure you’re signed in to iCloud, then quit and reopen WaterLogged."
			case .pendingRelaunch(let turningOn):
				turningOn
				? "Quit and reopen WaterLogged to start syncing with iCloud."
				: "Quit and reopen WaterLogged to stop syncing with iCloud. Your logbook stays on this device."
		}
	}
}
