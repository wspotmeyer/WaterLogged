//
//  CloudSyncSection.swift
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

import SwiftUI

/// Settings section with the opt-in "Sync with iCloud" switch. The preference is read
/// when the model container is created, so changes apply at the next launch.
/// See `WaterLoggedStore` and `CloudSyncStatus`.
struct CloudSyncSection: View {
	@AppStorage(WaterLoggedStore.iCloudSyncEnabledKey) private var iCloudSyncEnabled = false

	private var status: CloudSyncStatus {
		CloudSyncStatus(
			isEnabled: iCloudSyncEnabled,
			launchedEnabled: WaterLoggedStore.launchedWithCloudSyncEnabled,
			isActive: WaterLoggedStore.isCloudSyncActive
		)
	}

	var body: some View {
		Section {
			Toggle("Sync with iCloud", isOn: $iCloudSyncEnabled)
			if status == .syncing {
				LabeledContent("Status", value: CloudSyncMonitor.shared.activity.summary.text)
			}
		} header: {
			Text("iCloud")
		} footer: {
			// iCloud sync covers the SwiftData log book only; preferences live in
			// UserDefaults on each device. One Text so the note flows on from the
			// status message as a single paragraph.
			Text("\(status.message) Settings on this page, like appearance, units, and prior dive history, apply only to this device and don’t sync.")
		}
	}
}

#Preview {
	Form {
		CloudSyncSection()
	}
	.appFormStyle()
}
