//
//  CoordinateMapView.swift
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
import MapKit

/// A reusable map view that displays a marker at a given coordinate
/// and updates its camera position when the coordinate changes.
struct CoordinateMapView<MarkerContent: MapContent>: View {
	var latitude: Double
	var longitude: Double
	@MapContentBuilder var marker: () -> MarkerContent

	@State private var position: MapCameraPosition
	@State private var mapStyleOption: MapStyleOption = .hybrid

	init(latitude: Double, longitude: Double, @MapContentBuilder marker: @escaping () -> MarkerContent) {
		self.latitude = latitude
		self.longitude = longitude
		self.marker = marker
		_position = State(initialValue: Self.region(for: latitude, longitude: longitude))
	}

	private static func region(for latitude: Double, longitude: Double) -> MapCameraPosition {
		.region(
			MKCoordinateRegion(
				center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
				span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
			)
		)
	}

	var body: some View {
		Map(position: $position, interactionModes: [.pan, .rotate, .zoom, .pitch]) {
			marker()
		}
		.mapStyle(mapStyleOption.mapStyle)
		.mapControlVisibility(latitude == 0.0 && longitude == 0.0 ? .hidden : .visible)
		.clipShape(.rect(cornerRadius: 12))
		.frame(height: 250)
		.overlay(alignment: .bottomTrailing) {
			MapOverlayControls(
				mapStyleOption: $mapStyleOption,
				onRecenter: updatePosition
			)
			.padding(8)
		}
		.onAppear { updatePosition() }
		.onChange(of: latitude) { _, _ in updatePosition() }
		.onChange(of: longitude) { _, _ in updatePosition() }
	}

	private func updatePosition() {
		position = Self.region(for: latitude, longitude: longitude)
	}
}

#Preview {
	CoordinateMapView(latitude: 20.33435, longitude: -87.02615) {
		Marker("Palancar Horseshoe", coordinate: CLLocationCoordinate2D(latitude: 20.33435, longitude: -87.02615))
	}
	.padding()
}
