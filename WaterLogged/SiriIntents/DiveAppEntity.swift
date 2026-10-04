//
//  DiveAppEntity.swift
//  WaterLogged
//
//  Created by John Meyer on 6/27/26.
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
import UniformTypeIdentifiers

/// Sendable projection of `Dive` exposed to Siri and Spotlight via the
/// AppIntents framework. Indexed via `IndexedEntity` so dives are findable in
/// system search; tapping a result opens the dive's detail view via
/// `OpenDiveIntent`. Search keys on the dive's `displayTitle` (the dive's own
/// title, falling back to its site name, then "Dive #N"), which is what the
/// `title` `@Property` and the Spotlight `attributeSet.title` both carry.
///
/// `id` is the model's `externalId` (stable across CloudKit sync), display
/// strings are precomputed inside the `@MainActor` bridging initializer, and
/// the `title` `@Property` backs the generic "Find Dives" action via
/// `DiveEntityQuery`'s `EntityPropertyQuery`.
///
/// The type is `@MainActor` (the module default) because `@Property` wrappers
/// are mutable stored properties, which can't be `nonisolated` under this
/// project's isolation; a `@MainActor` value type is implicitly `Sendable`.
struct DiveAppEntity: IndexedEntity, Identifiable {

	static let typeDisplayRepresentation = TypeDisplayRepresentation(
		name: "Dive",
		numericFormat: "\(placeholder: .int) dives"
	)

	static let defaultQuery = DiveEntityQuery()

	// MARK: - Identity

	let id: String

	// MARK: - Queryable projected fields

	/// The dive's `displayTitle`. This is the field search matches against.
	@Property(title: "Title")
	var title: String

	// MARK: - Non-queryable projected fields

	let latitude: Double?
	let longitude: Double?

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

	var attributeSet: CSSearchableItemAttributeSet {
		let attributes = CSSearchableItemAttributeSet(contentType: .content)
		attributes.title = primaryDisplayTitle
		attributes.contentDescription = displaySubtitle
		attributes.keywords = ["dive", "scuba"]

		// Rank dives below the named records (sites/trips/buddies) so a large
		// logbook's dives don't crowd them out of results.
		attributes.rankingHint = SpotlightIndexer.diveRankingHint

		if let latitude, let longitude {
			attributes.latitude = NSNumber(value: latitude)
			attributes.longitude = NSNumber(value: longitude)
			attributes.supportsNavigation = true
		}

		return attributes
	}
}

// MARK: - Bridging from the SwiftData model

extension DiveAppEntity {
	/// Creates an entity projection from a SwiftData `Dive`. Must be called on
	/// the main actor because `Dive` (and its `site` relationship) are
	/// `@MainActor`.
	@MainActor
	init(from dive: Dive) {
		// Subtitle: "Dive #N · <date>", appending the site name when the dive's
		// own title is being shown as the primary title (so the location still
		// surfaces somewhere) and there is a site.
		let dateString = dive.date.formatted(date: .abbreviated, time: .omitted)
		var subtitle = "Dive #\(dive.diveNumber) · \(dateString)"
		if let siteName = dive.site?.name, !siteName.isEmpty, dive.displayTitle != siteName {
			subtitle += " · \(siteName)"
		}

		// Initialize the plain stored properties first; the `@Property`
		// wrapper takes its default storage from the `@Property(title:)`
		// macro, so its wrapped value is then set through its setter.
		self.id = dive.externalId
		self.latitude = dive.site?.latitude ?? dive.startLatitude
		self.longitude = dive.site?.longitude ?? dive.startLongitude
		self.primaryDisplayTitle = dive.displayTitle
		self.displaySubtitle = subtitle

		self.title = dive.displayTitle
	}
}
