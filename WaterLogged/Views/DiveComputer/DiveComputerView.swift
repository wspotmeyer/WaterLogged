//
//  DiveComputerView.swift
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
import SwiftData

struct DiveComputerView: View {
	@Environment(\.modelContext) private var modelContext
	@Environment(\.dismiss) private var dismiss

	@State private var manager = DiveComputerManager()

	var body: some View {
		NavigationStack {
			Group {
				switch manager.phase {
					case .idle, .scanning:
						DeviceScanningView(
							devices: manager.discoveredDevices,
							downloadNewOnly: $manager.downloadNewOnly,
							onSelect: { device in
								manager.connectAndDownload(device, context: modelContext)
							}
						)

					case .connecting(let deviceName):
						DeviceConnectingView(deviceName: deviceName)

					case .downloading(let progress):
						DiveTransferView(progress: progress)

					case .reviewing:
						DiveImportConfirmationView(
							dives: manager.downloadedDives,
							transferSummary: manager.lastTransfer?.formatted,
							onImport: { selectedDives in
								manager.importDives(selectedDives, into: modelContext)
							}
						)

					case .importing:
						VStack {
							ProgressView("Importing dives…")
						}
						.frame(maxWidth: .infinity, maxHeight: .infinity)

					case .complete(let count):
						ContentUnavailableView {
							Label("Import Complete", systemImage: "checkmark.circle.fill")
						} description: {
							Text("\(count) dive\(count == 1 ? "" : "s") imported successfully.")
						} actions: {
							Button("Done") {
								dismiss()
							}
							.buttonStyle(.borderedProminent)
						}

					case .error(let message):
						ContentUnavailableView {
							Label("Error", systemImage: "exclamationmark.triangle")
						} description: {
							Text(message)
						} actions: {
							Button("Try Again") {
								manager.startScanning()
							}
							.buttonStyle(.borderedProminent)
						}
				}
			}
			.appGradient()
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel", systemImage: "xmark") {
						manager.cancel()
						dismiss()
					}
				}
			}
		}
		.onAppear {
			manager.startScanning()
		}
		.onDisappear {
			manager.cancel()
		}
	}
}
