//
//  TripAppEntity.swift
//  WaterLogged
//
//  Created by John Meyer on 6/9/26.
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
//

import AppIntents
import CoreSpotlight
import Foundation

/// Sendable projection of `Trip` exposed to Siri and Spotlight. Date-range and
/// dive-count strings are precomputed inside the `@MainActor` bridging
/// initializer because both `Trip.dateRangeFormatted` and the `dives`
/// relationship live on the main actor.
///
/// Conforms to `IndexedEntity` so trips are donated to the Spotlight index
/// alongside dive sites and buddies; searching a place like "Cozumel" surfaces
/// trips whose name or location contains it, and tapping the result opens the
/// trip via `OpenTripIntent`.
nonisolated struct TripAppEntity: IndexedEntity, Identifiable, Sendable {

	static let typeDisplayRepresentation = TypeDisplayRepresentation(
		name: "Trip",
		numericFormat: "\(placeholder: .int) trips"
	)

	static let defaultQuery = TripEntityQuery()

	// MARK: - Identity

	let id: String

	// MARK: - Projected fields

	let name: String
	let startDate: Date
	let endDate: Date
	let location: String
	let diveCount: Int

	// MARK: - Precomputed display strings

	let primaryDisplayTitle: String
	let displaySubtitle: String

	// MARK: - Display

	var displayRepresentation: DisplayRepresentation {
		DisplayRepresentation(
			title: "\(primaryDisplayTitle)",
			subtitle: "\(displaySubtitle)"
		)
	}

	// MARK: - Spotlight indexing

	/// Spotlight metadata for the index. The system also indexes the
	/// `displayRepresentation`; this adds the trip's location as a searchable
	/// keyword so place queries like "Cozumel" find the trip.
	var attributeSet: CSSearchableItemAttributeSet {
		let attributes = CSSearchableItemAttributeSet(contentType: .content)
		attributes.title = primaryDisplayTitle
		attributes.contentDescription = displaySubtitle
		attributes.contentCreationDate = startDate

		var keywords = ["trip", "scuba"]
		if !location.isEmpty { keywords.append(location) }
		attributes.keywords = keywords

		attributes.rankingHint = SpotlightIndexer.primaryRankingHint

		return attributes
	}
}

// MARK: - Bridging from the SwiftData model

extension TripAppEntity {
	/// Creates an entity projection from a SwiftData `Trip`. Must be
	/// called on the main actor — `Trip.dateRangeFormatted` and the
	/// `dives` relationship are `@MainActor`.
	@MainActor
	init(from trip: Trip) {
		self.id = trip.externalId
		self.name = trip.name
		self.startDate = trip.startDate
		self.endDate = trip.endDate
		self.location = trip.location
		self.diveCount = trip.diveCount

		self.primaryDisplayTitle = trip.name.isEmpty ? "Untitled Trip" : trip.name

		// Subtitle: "<date range> · N dives" or just "<date range>" if no
		// dives are logged against the trip yet.
		let dateRange = trip.dateRangeFormatted
		if trip.diveCount == 0 {
			self.displaySubtitle = dateRange
		} else {
			let countLabel = trip.diveCount == 1 ? "1 dive" : "\(trip.diveCount) dives"
			self.displaySubtitle = "\(dateRange) · \(countLabel)"
		}
	}
}
