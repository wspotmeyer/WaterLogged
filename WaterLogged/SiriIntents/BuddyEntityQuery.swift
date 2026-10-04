//
//  BuddyEntityQuery.swift
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
import SwiftData

/// Resolves `BuddyAppEntity` values for Siri, Shortcuts, Spotlight, and Apple
/// Intelligence.
///
/// Conforms to `EntityStringQuery` so spoken text like "John" can be resolved
/// to a `BuddyAppEntity`, to `EntityPropertyQuery` so the Shortcuts app offers
/// a generic "Find Dive Buddies" action, and to `IndexedEntityQuery` so the
/// system can refresh specific buddies in the Spotlight index on demand. Per
/// CLAUDE.md text matching uses `localizedStandardContains` (locale-aware,
/// diacritic- and case-insensitive), which `#Predicate` doesn't support — so we
/// fetch all buddies and filter in memory. Buddy lists are small (tens to a
/// couple hundred) so this is fine.
nonisolated struct BuddyEntityQuery: EntityStringQuery, EntityPropertyQuery {

	/// A Sendable, main-actor-evaluated predicate over a `BuddyAppEntity`.
	struct BuddyComparator: Sendable {
		let matches: @MainActor @Sendable (BuddyAppEntity) -> Bool
	}

	nonisolated(unsafe) static let properties = QueryProperties {
		Property(\BuddyAppEntity.$formattedName) {
			ContainsComparator { value in
				BuddyComparator { $0.formattedName.localizedStandardContains(value) }
			}
		}
		Property(\BuddyAppEntity.$givenName) {
			ContainsComparator { value in
				BuddyComparator { $0.givenName.localizedStandardContains(value) }
			}
		}
		Property(\BuddyAppEntity.$familyName) {
			ContainsComparator { value in
				BuddyComparator { $0.familyName.localizedStandardContains(value) }
			}
		}
		Property(\BuddyAppEntity.$diveCount) {
			EqualToComparator { value in BuddyComparator { $0.diveCount == value } }
			GreaterThanComparator { value in BuddyComparator { $0.diveCount > value } }
			GreaterThanOrEqualToComparator { value in BuddyComparator { $0.diveCount >= value } }
			LessThanComparator { value in BuddyComparator { $0.diveCount < value } }
		}
		Property(\BuddyAppEntity.$isRetired) {
			EqualToComparator { value in BuddyComparator { $0.isRetired == value } }
		}
	}

	/// No per-field sort options are offered yet; results use the fixed
	/// family-name-then-given-name order applied in `entities(matching:)`.
	nonisolated(unsafe) static let sortingOptions = SortingOptions { }

	/// Returns the buddies matching the user-composed comparators. Results sort
	/// by family name then given name so the list reads like a contacts list.
	func entities(
		matching comparators: [BuddyComparator],
		mode: ComparatorMode,
		sortedBy: [EntityQuerySort<BuddyAppEntity>],
		limit: Int?
	) async throws -> [BuddyAppEntity] {
		try await MainActor.run {
			let context = ModelContext(WaterLoggedStore.shared)
			let descriptor = FetchDescriptor<Buddy>(
				sortBy: [
					SortDescriptor(\Buddy.familyName, comparator: .localizedStandard),
					SortDescriptor(\Buddy.givenName, comparator: .localizedStandard)
				]
			)
			let buddies = try context.fetch(descriptor)

			var results = buddies.map(BuddyAppEntity.init(from:)).filter { entity in
				switch mode {
					case .and: return comparators.allSatisfy { $0.matches(entity) }
					case .or:  return comparators.isEmpty || comparators.contains { $0.matches(entity) }
					@unknown default: return comparators.allSatisfy { $0.matches(entity) }
				}
			}

			if let limit {
				results = Array(results.prefix(limit))
			}
			return results
		}
	}

	func entities(for identifiers: [BuddyAppEntity.ID]) async throws -> [BuddyAppEntity] {
		try await MainActor.run {
			let context = ModelContext(WaterLoggedStore.shared)
			let predicate = #Predicate<Buddy> { buddy in
				identifiers.contains(buddy.externalId)
			}
			let descriptor = FetchDescriptor<Buddy>(predicate: predicate)
			let buddies = try context.fetch(descriptor)
			return buddies.map(BuddyAppEntity.init(from:))
		}
	}

	/// Suggestions are sorted by family name then given name so the picker
	/// reads like a contacts list.
	func suggestedEntities() async throws -> [BuddyAppEntity] {
		try await MainActor.run {
			let context = ModelContext(WaterLoggedStore.shared)
			let descriptor = FetchDescriptor<Buddy>(
				sortBy: [
					SortDescriptor(\Buddy.familyName, comparator: .localizedStandard),
					SortDescriptor(\Buddy.givenName, comparator: .localizedStandard)
				]
			)
			let buddies = try context.fetch(descriptor)
			return buddies.map(BuddyAppEntity.init(from:))
		}
	}

	/// Free-text matching invoked when Siri resolves a parameter from spoken
	/// input (e.g. "with John" → search "John" against buddies).
	func entities(matching string: String) async throws -> [BuddyAppEntity] {
		try await MainActor.run {
			let context = ModelContext(WaterLoggedStore.shared)
			let buddies = try context.fetch(FetchDescriptor<Buddy>())
			let matches = buddies.filter { buddy in
				buddy.givenName.localizedStandardContains(string)
				|| buddy.familyName.localizedStandardContains(string)
				|| buddy.formattedName.localizedStandardContains(string)
			}
			return matches.map(BuddyAppEntity.init(from:))
		}
	}

}

extension BuddyEntityQuery: IndexedEntityQuery {
	func reindexEntities(for identifiers: [BuddyAppEntity.ID], indexDescription: CSSearchableIndexDescription) async throws {
		let entities = try await entities(for: identifiers)
		try await SpotlightIndexer.index(entities)
	}

	func reindexAllEntities(indexDescription: CSSearchableIndexDescription) async throws {
		let entities = try await MainActor.run {
			let context = ModelContext(WaterLoggedStore.shared)
			return try context.fetch(FetchDescriptor<Buddy>()).map(BuddyAppEntity.init(from:))
		}
		try await SpotlightIndexer.index(entities)
	}
}
