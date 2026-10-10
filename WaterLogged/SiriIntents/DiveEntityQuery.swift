//
//  DiveEntityQuery.swift
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
import SwiftData

/// Resolves `DiveAppEntity` values for Siri, Shortcuts, Spotlight, and Apple
/// Intelligence. Conforming to `EntityPropertyQuery` adds a generic "Find Dives"
/// action to the Shortcuts app; `IndexedEntityQuery` lets the system refresh
/// specific dives in the Spotlight index on demand. Matching keys on the dive's
/// `displayTitle` (projected as `DiveAppEntity.title`) using
/// `localizedStandardContains` (which `#Predicate` doesn't support), so the
/// comparators are evaluated in memory over the fetched dives.
nonisolated struct DiveEntityQuery: EntityPropertyQuery {

	/// A Sendable, main-actor-evaluated predicate over a `DiveAppEntity`.
	struct DiveComparator: Sendable {
		let matches: @MainActor @Sendable (DiveAppEntity) -> Bool
	}

	nonisolated(unsafe) static let properties = QueryProperties {
		Property(\DiveAppEntity.$title) {
			ContainsComparator { value in
				DiveComparator { $0.title.localizedStandardContains(value) }
			}
		}
	}

	/// No per-field sort options are offered yet; results use the fixed
	/// newest-first order applied in `entities(matching:)`.
	nonisolated(unsafe) static let sortingOptions = SortingOptions { }

	/// Returns the dives matching the user-composed comparators. Results sort
	/// newest first, matching the log book's default order.
	func entities(
		matching comparators: [DiveComparator],
		mode: ComparatorMode,
		sortedBy: [EntityQuerySort<DiveAppEntity>],
		limit: Int?
	) async throws -> [DiveAppEntity] {
		try await MainActor.run {
			let context = ModelContext(WaterLoggedStore.shared)
			let descriptor = FetchDescriptor<Dive>(
				sortBy: [
					SortDescriptor(\Dive.date, order: .reverse),
					SortDescriptor(\Dive.diveNumber, order: .reverse)
				]
			)
			let dives = try context.fetch(descriptor)

			var results = dives.map(DiveAppEntity.init(from:)).filter { entity in
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

	func entities(for identifiers: [DiveAppEntity.ID]) async throws -> [DiveAppEntity] {
		try await MainActor.run {
			let context = ModelContext(WaterLoggedStore.shared)
			let predicate = #Predicate<Dive> { dive in
				identifiers.contains(dive.externalId)
			}
			let descriptor = FetchDescriptor<Dive>(predicate: predicate)
			let dives = try context.fetch(descriptor)
			return dives.map(DiveAppEntity.init(from:))
		}
	}

	func suggestedEntities() async throws -> [DiveAppEntity] {
		try await MainActor.run {
			let context = ModelContext(WaterLoggedStore.shared)
			var descriptor = FetchDescriptor<Dive>(
				sortBy: [
					SortDescriptor(\Dive.date, order: .reverse),
					SortDescriptor(\Dive.diveNumber, order: .reverse)
				]
			)
			descriptor.fetchLimit = 50
			let dives = try context.fetch(descriptor)
			return dives.map(DiveAppEntity.init(from:))
		}
	}

}

extension DiveEntityQuery: IndexedEntityQuery {
	func reindexEntities(for identifiers: [DiveAppEntity.ID], indexDescription: CSSearchableIndexDescription) async throws {
		let entities = try await entities(for: identifiers)
		try await SpotlightIndexer.index(entities)
	}

	func reindexAllEntities(indexDescription: CSSearchableIndexDescription) async throws {
		let entities = try await MainActor.run {
			let context = ModelContext(WaterLoggedStore.shared)
			return try context.fetch(FetchDescriptor<Dive>()).map(DiveAppEntity.init(from:))
		}
		try await SpotlightIndexer.index(entities)
	}
}
