//
//  DeviceRowView.swift
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

struct DeviceRowView: View {
	let device: DiscoveredDevice

	var body: some View {
		HStack {
			brandImage
				.resizable()
				.scaledToFit()
				.font(.title2)
				.foregroundStyle(.tint)
				.frame(width: 32, height: 24)

			VStack(alignment: .leading) {
				Text(device.name)
					.font(.headline)
				Text(device.brand.rawValue)
					.font(.subheadline)
					.foregroundStyle(.secondary)

			}

			Spacer()

			SignalStrengthView(rssi: device.rssi)
		}
		.contentShape(.rect)
	}

	private var brandImage: Image {
		switch device.brand {
			case .shearwater:
				Image(.shearwaterLogo)
			case .oceanic, .atomics:
				Image(.oceanicLogo)
			case .suunto:
				Image(.suuntoLogo)
			case .mares:
				Image(.maresLogo)
			case .scubapro:
				Image(.scubaproLogo)
			case .cressi:
				Image(.cressiLogo)
			case .heinrichsWeikamp, .garmin, .generic:
				Image(systemName: "sensor.tag.radiowaves.forward")
		}
	}
}

/// Displays a signal strength indicator based on RSSI value.
private struct SignalStrengthView: View {
	let rssi: Int

	var body: some View {
		HStack(spacing: 2) {
			ForEach(0..<4) { bar in
				RoundedRectangle(cornerRadius: 1)
					.fill(bar < signalBars ? Color.accentColor : Color.secondary.opacity(0.3))
					.frame(width: 4, height: CGFloat(6 + bar * 3))
			}
		}
		.frame(height: 18)
	}

	private var signalBars: Int {
		if rssi >= -50 { return 4 }
		if rssi >= -65 { return 3 }
		if rssi >= -80 { return 2 }
		if rssi >= -95 { return 1 }
		return 0
	}
}
