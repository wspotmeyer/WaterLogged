//
//  BuddyAppEntity.swift
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

/// Sendable projection of `Buddy` exposed to Siri and Spotlight. Indexed via
/// `IndexedEntity` so buddies are findable in system search; tapping a result
/// opens the buddy's detail view via `OpenBuddyIntent`. Also the subject of the
/// generic "Find Dive Buddies" action via `BuddyEntityQuery`'s
/// `EntityPropertyQuery` conformance.
///
/// The type is `@MainActor` (the module default) because `@Property` wrappers
/// are mutable stored properties, which can't be `nonisolated` under this
/// project's isolation; a `@MainActor` value type is implicitly `Sendable`.
struct BuddyAppEntity: IndexedEntity, Identifiable {

	static let typeDisplayRepresentation = TypeDisplayRepresentation(
		name: "Dive Buddy",
		numericFormat: "\(placeholder: .int) dive buddies"
	)

	static let defaultQuery = BuddyEntityQuery()

	// MARK: - Identity

	let id: String

	// MARK: - Queryable projected fields

	@Property(title: "Given Name")
	var givenName: String

	@Property(title: "Family Name")
	var familyName: String

	@Property(title: "Name")
	var formattedName: String

	@Property(title: "Number of Dives")
	var diveCount: Int

	@Property(title: "Retired")
	var isRetired: Bool

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
		attributes.keywords = ["dive buddy", "scuba", primaryDisplayTitle]
		attributes.rankingHint = SpotlightIndexer.primaryRankingHint
		return attributes
	}
}

// MARK: - Bridging from the SwiftData model

extension BuddyAppEntity {
	/// Creates an entity projection from a SwiftData `Buddy`. Must be called on
	/// the main actor because `Buddy.formattedName` and the `dives`
	/// relationship are `@MainActor`.
	@MainActor
	init(from buddy: Buddy) {
		let diveCount = buddy.dives?.count ?? 0
		let isRetired = buddy.isRetired

		// Subtitle: "N dives" plus a "(retired)" suffix when applicable so the
		// Shortcuts picker can distinguish active from retired buddies.
		let countLabel = diveCount == 1 ? "1 dive" : "\(diveCount) dives"
		let subtitle = isRetired ? "\(countLabel) · retired" : countLabel

		// Initialize the plain stored properties first; the `@Property`
		// wrappers take their default storage from the `@Property(title:)`
		// macro, so their wrapped values are then set through their setters.
		self.id = buddy.externalId
		self.primaryDisplayTitle = buddy.formattedName.isEmpty ? "Unnamed Buddy" : buddy.formattedName
		self.displaySubtitle = subtitle

		self.givenName = buddy.givenName
		self.familyName = buddy.familyName
		self.formattedName = buddy.formattedName
		self.diveCount = diveCount
		self.isRetired = isRetired
	}
}
