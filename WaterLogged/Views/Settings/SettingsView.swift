//
//  SettingsView.swift
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

enum AppearanceMode: String, CaseIterable, Identifiable {
	case system
	case light
	case dark

	var id: String { rawValue }

	var displayName: String {
		switch self {
			case .system: "System"
			case .light:  "Light"
			case .dark:   "Dark"
		}
	}

	var colorScheme: ColorScheme? {
		switch self {
			case .system: nil
			case .light:  .light
			case .dark:   .dark
		}
	}
}

struct SettingsView: View {
	var body: some View {
#if os(macOS)
		// The macOS `Settings` scene sizes the window via its own `.frame`; the
		// in-window content flexes so it also fits the Settings tab.
		SettingsFormContent()
#else
		NavigationStack {
			SettingsFormContent()
				.navigationTitle("Settings")
		}
#endif
	}
}

private struct SettingsFormContent: View {
	@AppStorage("unitSystem") private var unitSystem: UnitSystem = .imperial
	@AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system

	var body: some View {
		Form {
			Group {
				Section("Appearance") {
					Picker("Appearance", selection: $appearanceMode) {
						ForEach(AppearanceMode.allCases) { mode in
							Text(mode.displayName).tag(mode)
						}
					}
					.pickerStyle(.segmented)
				}

				Section("Units") {
					Picker("Unit System", selection: $unitSystem) {
						ForEach(UnitSystem.allCases) { system in
							Text(system.displayName).tag(system)
						}
					}
					.pickerStyle(.segmented)

					Text(unitSystem == .metric
						 ? "Depth in meters, temperature in °C, pressure in bar, weight in kg, volume in liters."
						 : "Depth in feet, temperature in °F, pressure in PSI, weight in lbs, volume in cubic feet.")
					.font(.caption)
					.foregroundStyle(.secondary)
				}

				PriorDiveHistorySection()

				CloudSyncSection()
			}
			.tileListRowBackground()
		}
		.formStyle(.grouped)
		.frame(maxWidth: 500)
		.frame(maxWidth: .infinity)
		.appGradientScrollBackground()
		.navigationTitle("Settings")
#if !os(macOS)
		.navigationBarTitleDisplayMode(.inline)
#endif
	}
}

#Preview {
	SettingsView()
}
