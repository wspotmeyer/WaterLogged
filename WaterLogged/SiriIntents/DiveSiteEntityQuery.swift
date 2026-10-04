//
//  DiveSiteEntityQuery.swift
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

/// Resolves `DiveSiteAppEntity` values for Siri, Shortcuts, Spotlight, and
/// Apple Intelligence. Conforming to `EntityPropertyQuery` adds a generic
/// "Find Dive Sites" action to the Shortcuts app; `IndexedEntityQuery` lets the
/// system refresh specific sites in the Spotlight index on demand. Text matching
/// uses `localizedStandardContains` (which `#Predicate` doesn't support), so the
/// comparators are evaluated in memory over the fetched sites.
nonisolated struct DiveSiteEntityQuery: EntityPropertyQuery {

	/// A Sendable, main-actor-evaluated predicate over a `DiveSiteAppEntity`.
	struct SiteComparator: Sendable {
		let matches: @MainActor @Sendable (DiveSiteAppEntity) -> Bool
	}

	nonisolated(unsafe) static let properties = QueryProperties {
		Property(\DiveSiteAppEntity.$name) {
			ContainsComparator { value in
				SiteComparator { $0.name.localizedStandardContains(value) }
			}
		}
		Property(\DiveSiteAppEntity.$country) {
			ContainsComparator { value in
				SiteComparator { $0.country.localizedStandardContains(value) }
			}
		}
		Property(\DiveSiteAppEntity.$region) {
			ContainsComparator { value in
				SiteComparator { $0.region.localizedStandardContains(value) }
			}
		}
		Property(\DiveSiteAppEntity.$diveCount) {
			EqualToComparator { value in SiteComparator { $0.diveCount == value } }
			GreaterThanComparator { value in SiteComparator { $0.diveCount > value } }
			GreaterThanOrEqualToComparator { value in SiteComparator { $0.diveCount >= value } }
			LessThanComparator { value in SiteComparator { $0.diveCount < value } }
		}
	}

	/// No per-field sort options are offered yet; results use the fixed
	/// alphabetical order applied in `entities(matching:)`.
	nonisolated(unsafe) static let sortingOptions = SortingOptions { }

	/// Returns the sites matching the user-composed comparators. Results sort
	/// alphabetically by name.
	func entities(
		matching comparators: [SiteComparator],
		mode: ComparatorMode,
		sortedBy: [EntityQuerySort<DiveSiteAppEntity>],
		limit: Int?
	) async throws -> [DiveSiteAppEntity] {
		try await MainActor.run {
			let context = ModelContext(WaterLoggedStore.shared)
			let descriptor = FetchDescriptor<DiveSite>(
				sortBy: [SortDescriptor(\DiveSite.name, comparator: .localizedStandard)]
			)
			let sites = try context.fetch(descriptor)

			var results = sites.map(DiveSiteAppEntity.init(from:)).filter { entity in
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

	func entities(for identifiers: [DiveSiteAppEntity.ID]) async throws -> [DiveSiteAppEntity] {
		try await MainActor.run {
			let context = ModelContext(WaterLoggedStore.shared)
			let predicate = #Predicate<DiveSite> { site in
				identifiers.contains(site.externalId)
			}
			let descriptor = FetchDescriptor<DiveSite>(predicate: predicate)
			let sites = try context.fetch(descriptor)
			return sites.map(DiveSiteAppEntity.init(from:))
		}
	}

	func suggestedEntities() async throws -> [DiveSiteAppEntity] {
		try await MainActor.run {
			let context = ModelContext(WaterLoggedStore.shared)
			var descriptor = FetchDescriptor<DiveSite>(
				sortBy: [SortDescriptor(\DiveSite.name, comparator: .localizedStandard)]
			)
			descriptor.fetchLimit = 50
			let sites = try context.fetch(descriptor)
			return sites.map(DiveSiteAppEntity.init(from:))
		}
	}

}

extension DiveSiteEntityQuery: IndexedEntityQuery {
	func reindexEntities(for identifiers: [DiveSiteAppEntity.ID], indexDescription: CSSearchableIndexDescription) async throws {
		let entities = try await entities(for: identifiers)
		try await SpotlightIndexer.index(entities)
	}

	func reindexAllEntities(indexDescription: CSSearchableIndexDescription) async throws {
		let entities = try await MainActor.run {
			let context = ModelContext(WaterLoggedStore.shared)
			return try context.fetch(FetchDescriptor<DiveSite>()).map(DiveSiteAppEntity.init(from:))
		}
		try await SpotlightIndexer.index(entities)
	}
}
