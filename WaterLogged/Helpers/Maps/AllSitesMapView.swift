//
//  AllSitesMapView.swift
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

/// A map showing all dive sites that have coordinates.
/// When no annotated sites exist, displays the provided `empty` content instead,
/// or a plain map if no empty content is specified.
struct AllSitesMapView<Empty: View>: View {
	@Query private var sites: [DiveSite]
	@Environment(SharedMapState.self) private var mapState
	private let empty: Empty?

	init(@ViewBuilder empty: () -> Empty) {
		self.empty = empty()
	}

	private var annotatedSites: [DiveSite] {
		sites.filter { $0.latitude != nil && $0.longitude != nil && !($0.dives ?? []).isEmpty }
	}

	var body: some View {
		if annotatedSites.isEmpty, let empty {
			empty
		} else {
			Map(initialPosition: mapState.cameraPosition) {
				ForEach(annotatedSites) { site in
					Annotation(
						LocalizedStringKey(site.name),
						coordinate: CLLocationCoordinate2D(
							latitude: site.latitude ?? 0,
							longitude: site.longitude ?? 0
						)
					) {
						Button {
							NavigationRouter.shared.pending = .diveSite(id: site.externalId)
						} label: {
							ScubaFlagMarker(diveCount: site.dives?.count ?? 0)
						}
						.buttonStyle(.plain)
					}
				}
			}
			.mapStyle(.hybrid)
			.onMapCameraChange { context in
				mapState.cameraPosition = .camera(context.camera)
			}
		}
	}
}

extension AllSitesMapView where Empty == Never {
	init() {
		self.empty = nil
	}
}

#Preview {
	AllSitesMapView {
		ContentUnavailableView(
			"No Dive Sites",
			systemImage: "mappin.slash",
			description: Text("Add a dive site with coordinates to see it on the map.")
		)
	}
	.environment(SharedMapState())
	.modelContainer(PreviewContainer.container)
}
