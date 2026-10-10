//
//  SpotlightIndexer.swift
//  WaterLogged
//
//  Created by John Meyer on 6/16/26.
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
import SwiftData

/// Donates WaterLogged's `IndexedEntity` projections to a private, on-device
/// Spotlight index. Indexing makes dives, dive sites, trips, and buddies
/// findable in system search; tapping a result opens the matching detail view
/// via the per-type `OpenIntent`. Dives are matched on their `displayTitle`.
///
/// A named index is used rather than `CSSearchableIndex.default()` per Apple's
/// guidance (the default index is for prototyping only). The index lives only
/// on the device and is never synchronized to Apple.
nonisolated enum SpotlightIndexer {

	/// The app's named Spotlight index. Each entity type is reindexed wholesale
	/// on launch, so a single shared index keeps things simple.
	private static let indexName = "WaterLoggedEntities"

	/// Relative Spotlight ranking hints (`CSSearchableItemAttributeSet.rankingHint`,
	/// 0–100; higher shows more prominently). Named records — sites, trips, and
	/// buddies — outrank dives so that a large log book's many dives don't crowd
	/// them out of search results. Every dive is still indexed and findable,
	/// just ranked below the named records. Ranking is only a hint; the system
	/// makes the final ordering decision.
	static let primaryRankingHint = NSNumber(value: 100)
	static let diveRankingHint = NSNumber(value: 1)

	/// Donates a batch of indexed entities to the Spotlight index.
	static func index<Entity: IndexedEntity>(_ entities: [Entity]) async throws {
		guard !entities.isEmpty else { return }
		try await CSSearchableIndex(name: indexName).indexAppEntities(entities)
	}

	/// Reindexes every dive, dive site, trip, and buddy. Called on launch and
	/// after the log book changes so search results stay current. Failures are
	/// surfaced to the caller; Spotlight indexing is best-effort and a thrown
	/// error shouldn't be treated as fatal by callers.
	@MainActor
	static func indexAll() async throws {
		let context = ModelContext(WaterLoggedStore.shared)

		let dives = try context.fetch(FetchDescriptor<Dive>())
			.map(DiveAppEntity.init(from:))
		let sites = try context.fetch(FetchDescriptor<DiveSite>())
			.map(DiveSiteAppEntity.init(from:))
		let trips = try context.fetch(FetchDescriptor<Trip>())
			.map(TripAppEntity.init(from:))
		let buddies = try context.fetch(FetchDescriptor<Buddy>())
			.map(BuddyAppEntity.init(from:))

		try await index(dives)
		try await index(sites)
		try await index(trips)
		try await index(buddies)
	}

	/// Removes every dive, site, trip, and buddy from the index. Used before a
	/// full reindex when a save included deletions, so removed items don't
	/// linger in search results (`indexAppEntities` only adds and updates — it
	/// never removes entries that are no longer present).
	static func purgeAll() async throws {
		let index = CSSearchableIndex(name: indexName)
		try await index.deleteAppEntities(ofType: DiveAppEntity.self)
		try await index.deleteAppEntities(ofType: DiveSiteAppEntity.self)
		try await index.deleteAppEntities(ofType: TripAppEntity.self)
		try await index.deleteAppEntities(ofType: BuddyAppEntity.self)
	}
}
