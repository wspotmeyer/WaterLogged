//
//  DiveSiteAppEntity.swift
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
import UniformTypeIdentifiers

/// Sendable projection of `DiveSite` exposed to Siri and Spotlight via the
/// AppIntents framework. Indexed via `IndexedEntity` so sites are findable in
/// system search; tapping a result opens the site's detail view via
/// `OpenDiveSiteIntent`. `id` is the model's `externalId` (stable across
/// CloudKit sync), display strings are precomputed inside the `@MainActor`
/// bridging initializer, and the `@Property` fields back the generic
/// "Find Dive Sites" action via `DiveSiteEntityQuery`'s `EntityPropertyQuery`.
///
/// The type is `@MainActor` (the module default) because `@Property` wrappers
/// are mutable stored properties, which can't be `nonisolated` under this
/// project's isolation; a `@MainActor` value type is implicitly `Sendable`.
struct DiveSiteAppEntity: IndexedEntity, Identifiable {

	static let typeDisplayRepresentation = TypeDisplayRepresentation(
		name: "Dive Site",
		numericFormat: "\(placeholder: .int) dive sites"
	)

	static let defaultQuery = DiveSiteEntityQuery()

	// MARK: - Identity

	let id: String

	// MARK: - Queryable projected fields

	@Property(title: "Name")
	var name: String

	@Property(title: "Country")
	var country: String

	@Property(title: "Region")
	var region: String

	@Property(title: "Number of Dives")
	var diveCount: Int

	// MARK: - Non-queryable projected fields

	let latitude: Double?
	let longitude: Double?
	let totalDiveTimeSeconds: Int

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

		var keywords = ["dive site", "scuba"]
		if !country.isEmpty { keywords.append(country) }
		if !region.isEmpty { keywords.append(region) }
		attributes.keywords = keywords

		if let latitude, let longitude {
			attributes.latitude = NSNumber(value: latitude)
			attributes.longitude = NSNumber(value: longitude)
			attributes.supportsNavigation = true
		}

		attributes.rankingHint = SpotlightIndexer.primaryRankingHint

		return attributes
	}
}

// MARK: - Bridging from the SwiftData model

extension DiveSiteAppEntity {
	/// Creates an entity projection from a SwiftData `DiveSite`. Must be
	/// called on the main actor because `DiveSite` (and its `dives`
	/// relationship) are `@MainActor`.
	@MainActor
	init(from site: DiveSite) {
		let diveCount = site.dives?.count ?? 0

		// Subtitle: "<region or country> · N dives" (with the country falling
		// back if region is empty, and the whole location segment dropping if
		// both are empty so we don't show a leading separator).
		let location: String
		if !site.region.isEmpty {
			location = site.region
		} else if !site.country.isEmpty {
			location = site.country
		} else {
			location = ""
		}
		let countLabel = diveCount == 1 ? "1 dive" : "\(diveCount) dives"
		let subtitle = location.isEmpty ? countLabel : "\(location) · \(countLabel)"

		// Initialize the plain stored properties first; the `@Property`
		// wrappers take their default storage from the `@Property(title:)`
		// macro, so their wrapped values are then set through their setters.
		self.id = site.externalId
		self.latitude = site.latitude
		self.longitude = site.longitude
		self.totalDiveTimeSeconds = site.totalDiveTimeSeconds
		self.primaryDisplayTitle = site.name.isEmpty ? "Unnamed Site" : site.name
		self.displaySubtitle = subtitle

		self.name = site.name
		self.country = site.country
		self.region = site.region
		self.diveCount = diveCount
	}
}
