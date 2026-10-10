//
//  TripsSection.swift
//  WaterLogged
//
//  Created by John Meyer on 10/4/26.
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

/// The collapsible "Trips" section on the buddy, dive site, gas mix, and equipment detail views:
/// every trip the given dives belong to, each linking to its `TripDetailView`.
struct TripsSection: View {
	let dives: [Dive]?

	@State private var isExpanded = false

	/// The trips the dives belong to, in dive-date order, without duplicates.
	static func trips(for dives: [Dive]) -> [Trip] {
		var seenTripIDs: Set<PersistentIdentifier> = []
		var result: [Trip] = []
		for dive in dives.sorted(by: { $0.date < $1.date }) {
			guard let trip = dive.trip, !seenTripIDs.contains(trip.persistentModelID) else { continue }
			seenTripIDs.insert(trip.persistentModelID)
			result.append(trip)
		}
		return result
	}

	var body: some View {
		let trips = Self.trips(for: dives ?? [])
		if !trips.isEmpty {
			GroupBox {
				if isExpanded {
					VStack(spacing: 0) {
						ForEach(trips) { trip in
							NavigationLink {
								TripDetailView(trip: trip)
							} label: {
								HStack {
									Text(LocalizedStringKey(trip.name))
										.lineLimit(1)
									Spacer()
									Text(trip.dateRangeFormatted)
										.foregroundStyle(.secondary)
										.lineLimit(1)
									Image(systemName: "chevron.right")
										.font(.caption)
								}
								.padding(.top, 12)
							}
							.buttonStyle(.plain)
						}
					}
					.frame(maxWidth: .infinity, alignment: .leading)
				}
			} label: {
				HStack {
					Text("Trips")
						.font(.title2.bold())
					Spacer()
					TripCount(count: trips.count, font: .headline)
					DisclosureToggleButton(isExpanded: $isExpanded, subject: "Trips")
				}
			}
			.tileBackgroundStyle()
		}
	}
}
