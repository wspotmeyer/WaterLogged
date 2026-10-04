//
//  MapOverlayControls.swift
//  WaterLogged
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
import MapKit

/// User-selectable map styles offered by the in-map style picker.
enum MapStyleOption: String, CaseIterable, Identifiable {
	case standard
	case hybrid
	case imagery

	var id: String { rawValue }

	var label: String {
		switch self {
			case .standard: "Standard"
			case .hybrid: "Hybrid"
			case .imagery: "Satellite"
		}
	}

	var systemImage: String {
		switch self {
			case .standard: "map"
			case .hybrid: "globe.americas"
			case .imagery: "globe"
		}
	}

	var mapStyle: MapStyle {
		switch self {
			case .standard: .standard
			case .hybrid: .hybrid
			case .imagery: .imagery
		}
	}
}

/// Floating overlay control cluster for any of the app's map views.
/// Combines a map-style picker and a recenter button into a single Liquid Glass capsule.
struct MapOverlayControls: View {
	@Binding var mapStyleOption: MapStyleOption
	let onRecenter: () -> Void

	var body: some View {
		VStack(spacing: 4) {
			Menu {
				Picker("Map Style", selection: $mapStyleOption) {
					ForEach(MapStyleOption.allCases) { option in
						Label(option.label, systemImage: option.systemImage).tag(option)
					}
				}
				.pickerStyle(.inline)
			} label: {
				Label("Map Style", systemImage: "square.3.layers.3d")
					.labelStyle(.iconOnly)
					.padding(8)
					.contentShape(.rect)
			}
			.buttonStyle(.plain)
			.menuIndicator(.hidden)

			Button(action: onRecenter) {
				Label("Recenter", systemImage: "scope")
					.labelStyle(.iconOnly)
					.padding(8)
					.contentShape(.rect)
			}
			.buttonStyle(.plain)
		}
		.font(.title3)
		.foregroundStyle(.primary)
		.glassEffect(.regular.interactive(), in: .capsule)
	}
}
