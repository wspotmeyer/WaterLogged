//
//  DeviceScanningView.swift
//  WaterLogged
//
//  Created by John Meyer on 2/23/26.
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

struct DeviceScanningView: View {
	let devices: [DiscoveredDevice]
	@Binding var downloadNewOnly: Bool
	let onSelect: (DiscoveredDevice) -> Void

	var body: some View {
		VStack {
			if devices.isEmpty {
				ContentUnavailableView {
					Label("Searching for Dive Computers", systemImage: "antenna.radiowaves.left.and.right")
				} description: {
					Text("Make sure your dive computer is in transfer mode and nearby.")
				}
				.frame(maxHeight: .infinity)
			} else {
				List {
					Group {
						Section {
							ForEach(devices) { device in
								Button {
									onSelect(device)
								} label: {
									DeviceRowView(device: device)
								}
								.buttonStyle(.plain)
							}
						}

						Section {
							Toggle("New Dives Only", isOn: $downloadNewOnly)
						} footer: {
							Text("When enabled, dives that are already in your log book are skipped.")
						}
					}
					.tileListRowBackground()
				}
				.scrollContentBackground(.hidden)
				.frame(maxHeight: .infinity)
			}

			HStack {
				ProgressView()
				Text("Scanning…")
					.foregroundStyle(.secondary)
			}
			.padding(.bottom)
		}
		.frame(minHeight: 300)
	}
}
