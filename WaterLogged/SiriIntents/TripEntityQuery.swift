//
//  TripEntityQuery.swift
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

/// Resolves `TripAppEntity` values for Siri and Spotlight. Suggestions sort by
/// `endDate` descending — most recent trips first. `entities(for:)` is what
/// `OpenTripIntent` uses to turn a tapped Spotlight result back into a trip.
nonisolated struct TripEntityQuery: EntityQuery {

	func entities(for identifiers: [TripAppEntity.ID]) async throws -> [TripAppEntity] {
		try await MainActor.run {
			let context = ModelContext(WaterLoggedStore.shared)
			let predicate = #Predicate<Trip> { trip in
				identifiers.contains(trip.externalId)
			}
			let descriptor = FetchDescriptor<Trip>(predicate: predicate)
			let trips = try context.fetch(descriptor)
			return trips.map(TripAppEntity.init(from:))
		}
	}

	func suggestedEntities() async throws -> [TripAppEntity] {
		try await MainActor.run {
			let context = ModelContext(WaterLoggedStore.shared)
			var descriptor = FetchDescriptor<Trip>(
				sortBy: [SortDescriptor(\Trip.endDate, order: .reverse)]
			)
			descriptor.fetchLimit = 25
			let trips = try context.fetch(descriptor)
			return trips.map(TripAppEntity.init(from:))
		}
	}
}

extension TripEntityQuery: IndexedEntityQuery {
	func reindexEntities(for identifiers: [TripAppEntity.ID], indexDescription: CSSearchableIndexDescription) async throws {
		let entities = try await entities(for: identifiers)
		try await SpotlightIndexer.index(entities)
	}

	func reindexAllEntities(indexDescription: CSSearchableIndexDescription) async throws {
		let entities = try await MainActor.run {
			let context = ModelContext(WaterLoggedStore.shared)
			return try context.fetch(FetchDescriptor<Trip>()).map(TripAppEntity.init(from:))
		}
		try await SpotlightIndexer.index(entities)
	}
}
