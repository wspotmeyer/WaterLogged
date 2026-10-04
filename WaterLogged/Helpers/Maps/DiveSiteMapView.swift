//
//  DiveSiteMapView.swift
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
import MapKit

/// Displays a dive site on a map. When start and/or end coordinates are provided,
/// plots entry/exit markers with a directional arrow between them.
struct DiveSiteMapView: View {
	var diveSite: DiveSite
	var startLatitude: Double?
	var startLongitude: Double?
	var endLatitude: Double?
	var endLongitude: Double?

	private var siteCoordinate: CLLocationCoordinate2D? {
		guard let lat = diveSite.latitude, let lng = diveSite.longitude else { return nil }
		return CLLocationCoordinate2D(latitude: lat, longitude: lng)
	}

	private var startCoordinate: CLLocationCoordinate2D? {
		guard let lat = startLatitude, let lng = startLongitude else { return nil }
		return CLLocationCoordinate2D(latitude: lat, longitude: lng)
	}

	private var endCoordinate: CLLocationCoordinate2D? {
		guard let lat = endLatitude, let lng = endLongitude else { return nil }
		return CLLocationCoordinate2D(latitude: lat, longitude: lng)
	}

	private var hasGeolocations: Bool {
		startCoordinate != nil || endCoordinate != nil
	}

	@State private var position: MapCameraPosition
	@State private var mapStyleOption: MapStyleOption = .hybrid

	init(diveSite: DiveSite,
		 startLatitude: Double? = nil,
		 startLongitude: Double? = nil,
		 endLatitude: Double? = nil,
		 endLongitude: Double? = nil) {
		self.diveSite = diveSite
		self.startLatitude = startLatitude
		self.startLongitude = startLongitude
		self.endLatitude = endLatitude
		self.endLongitude = endLongitude

		let coordinates = Self.coordinates(
			site: diveSite,
			startLatitude: startLatitude, startLongitude: startLongitude,
			endLatitude: endLatitude, endLongitude: endLongitude
		)
		_position = State(initialValue: Self.region(for: coordinates))
	}

	private static func coordinates(
		site: DiveSite,
		startLatitude: Double?, startLongitude: Double?,
		endLatitude: Double?, endLongitude: Double?
	) -> [CLLocationCoordinate2D] {
		var coords: [CLLocationCoordinate2D] = []
		if let lat = site.latitude, let lng = site.longitude {
			coords.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
		}
		if let lat = startLatitude, let lng = startLongitude {
			coords.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
		}
		if let lat = endLatitude, let lng = endLongitude {
			coords.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
		}
		return coords
	}

	private static func region(for coordinates: [CLLocationCoordinate2D]) -> MapCameraPosition {
		guard !coordinates.isEmpty else { return .automatic }

		if coordinates.count == 1 {
			return .region(
				MKCoordinateRegion(
					center: coordinates[0],
					span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
				)
			)
		}
		let lats = coordinates.map(\.latitude)
		let lngs = coordinates.map(\.longitude)
		let center = CLLocationCoordinate2D(
			latitude: (lats.min()! + lats.max()!) / 2,
			longitude: (lngs.min()! + lngs.max()!) / 2
		)
		let latDelta = (lats.max()! - lats.min()!) * 1.5 + 0.005
		let lngDelta = (lngs.max()! - lngs.min()!) * 1.5 + 0.005
		return .region(
			MKCoordinateRegion(
				center: center,
				span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lngDelta)
			)
		)
	}

	var body: some View {
		if siteCoordinate != nil || hasGeolocations {
			Map(position: $position, interactionModes: [.pan, .rotate, .zoom, .pitch]) {
				if let site = siteCoordinate, let count = diveSite.dives?.count {
					Annotation(LocalizedStringKey(diveSite.name), coordinate: site) {
						ScubaFlagMarker(diveCount: count)
					}
				}

				if let start = startCoordinate {
					Annotation("Entry", coordinate: start) {
						DivePointMarker(color: .green)
					}
				}

				if let end = endCoordinate {
					Annotation("Exit", coordinate: end) {
						DivePointMarker(color: .red)
					}
				}

				if let start = startCoordinate, let end = endCoordinate {
					MapPolyline(coordinates: [start, end])
						.stroke(.blue, lineWidth: 3)
				}
			}
			.mapStyle(mapStyleOption.mapStyle)
			.mapControlVisibility(.visible)
			.clipShape(.rect(cornerRadius: 12))
			.frame(height: 300)
			.overlay(alignment: .bottomTrailing) {
				MapOverlayControls(
					mapStyleOption: $mapStyleOption,
					onRecenter: { updatePosition() }
				)
				.padding(8)
			}
			.onAppear { updatePosition() }
		}
	}

	private func updatePosition() {
		let coordinates = Self.coordinates(
			site: diveSite,
			startLatitude: startLatitude, startLongitude: startLongitude,
			endLatitude: endLatitude, endLongitude: endLongitude
		)
		guard !coordinates.isEmpty else { return }
		position = Self.region(for: coordinates)
	}
}

/// A small circular marker for entry/exit points on the dive map.
private struct DivePointMarker: View {
	var color: Color

	var body: some View {
		Circle()
			.fill(color)
			.frame(width: 14, height: 14)
			.overlay {
				Circle()
					.stroke(.white, lineWidth: 2)
			}
			.shadow(radius: 2)
	}
}

#Preview("Site Only") {
	do {
		let container = try ModelContainer(for: DiveSite.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
		return DiveSiteMapView(diveSite: DiveSite(name: "Palancar Horseshoe", latitude: 20.33435, longitude: -87.02615))
			.modelContainer(container)
			.padding()
	} catch {
		fatalError("Failed to create model container.")
	}
}

#Preview("With Entry & Exit") {
	do {
		let container = try ModelContainer(for: DiveSite.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
		return DiveSiteMapView(
			diveSite: DiveSite(name: "Palancar Horseshoe", latitude: 20.33435, longitude: -87.02615),
			startLatitude: 20.3320,
			startLongitude: -87.0240,
			endLatitude: 20.3365,
			endLongitude: -87.0285
		)
		.modelContainer(container)
		.padding()
	} catch {
		fatalError("Failed to create model container.")
	}
}
