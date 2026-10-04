//
//  GasMix.swift
//  WaterLogged
//
//  Created by John Meyer on 2/23/26.
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

import Foundation
import SwiftData

@Model
final class GasMix {
	var externalId: String = UUID().uuidString
	var name: String = "Air"         // e.g. "Air", "EAN32", "Trimix 21/35"
	var oxygenPercent: Double = 21.0    // e.g. 21.0
	var heliumPercent: Double = 0.0    // e.g. 0.0 for air/nitrox
	var argonPercent: Double = 0.0
	var hydrogenPercent: Double = 0.0

	/// Nitrogen as the balance of a mix: whatever is left once the gases a diver actually
	/// specifies are accounted for. Deriving it keeps a mix from summing past 100%, and means
	/// there is no separate stored figure that could contradict the other gases.
	nonisolated static func nitrogenPercent(
		oxygen: Double,
		helium: Double = 0,
		argon: Double = 0,
		hydrogen: Double = 0
	) -> Double {
		max(0, 100 - oxygen - helium - argon - hydrogen)
	}

	/// This mix's nitrogen share, derived from its other gases rather than stored.
	var nitrogenPercent: Double {
		Self.nitrogenPercent(
			oxygen: oxygenPercent,
			helium: heliumPercent,
			argon: argonPercent,
			hydrogen: hydrogenPercent
		)
	}

	/// The name to show for this mix: its own name, or its oxygen percentage when unnamed.
	var displayName: String {
		if name.isEmpty {
			return "O₂: \(Int(oxygenPercent))%"
		}
		return name
	}

	/// The mix's constituent gases. Oxygen always appears; the rest only when the mix contains them.
	var components: [GasComponent] {
		var components = [GasComponent(kind: .oxygen, fraction: oxygenPercent / 100)]
		let nitrogen = nitrogenPercent
		if nitrogen > 0 {
			components.append(GasComponent(kind: .nitrogen, fraction: nitrogen / 100))
		}
		if heliumPercent > 0 {
			components.append(GasComponent(kind: .helium, fraction: heliumPercent / 100))
		}
		if argonPercent > 0 {
			components.append(GasComponent(kind: .argon, fraction: argonPercent / 100))
		}
		if hydrogenPercent > 0 {
			components.append(GasComponent(kind: .hydrogen, fraction: hydrogenPercent / 100))
		}
		return components
	}

	/// The mix's components on a single line, such as "O₂ 32% · N₂ 68%".
	var componentSummary: String {
		components.map(\.summary).joined(separator: " · ")
	}

	@Relationship(deleteRule: .nullify, inverse: \Tank.gasMix)
	var tanks: [Tank]? = []

	var totalDiveTimeSeconds: Int {
		let dives = Set((tanks ?? []).compactMap(\.dive))
		return dives.reduce(0) { $0 + $1.durationSeconds }
	}

	init(
		externalId: String = UUID().uuidString,
		name: String = "Air",
		oxygenPercent: Double = 21.0,
		heliumPercent: Double = 0.0,
		argonPercent: Double = 0.0,
		hydrogenPercent: Double = 0.0
	) {
		self.externalId = externalId
		self.name = name
		self.oxygenPercent = oxygenPercent
		self.heliumPercent = heliumPercent
		self.argonPercent = argonPercent
		self.hydrogenPercent = hydrogenPercent
	}

	/// Finds the first existing gas mix with matching gas component
	/// percentages, or creates and inserts a new one.
	///
	/// - Parameter uddfId: Preserves a UDDF/extras `externalId` as the model's
	///   `externalId`, mirroring the `uddfId` parameter on `UDDFImporter`'s
	///   other `findOrCreate` methods. Checked first so that every tank
	///   referencing the same original gas mix resolves to the same restored
	///   record instead of one keyed off a floating-point percentage round
	///   trip. Only set on newly created entities.
	static func findOrCreate(
		name: String = "Air",
		oxygenPercent: Double = 21.0,
		heliumPercent: Double = 0.0,
		argonPercent: Double = 0.0,
		hydrogenPercent: Double = 0.0,
		uddfId: String? = nil,
		in context: ModelContext
	) -> GasMix {
		if let uddfId {
			var idDescriptor = FetchDescriptor<GasMix>(
				predicate: #Predicate<GasMix> { $0.externalId == uddfId }
			)
			idDescriptor.fetchLimit = 1
			if let existing = try? context.fetch(idDescriptor).first {
				return existing
			}
		}

		let o2 = oxygenPercent
		let he = heliumPercent
		let ar = argonPercent
		let h2 = hydrogenPercent
		var descriptor = FetchDescriptor<GasMix>(
			predicate: #Predicate<GasMix> {
				$0.oxygenPercent == o2
				&& $0.heliumPercent == he
				&& $0.argonPercent == ar
				&& $0.hydrogenPercent == h2
			}
		)
		descriptor.fetchLimit = 1

		if let existing = try? context.fetch(descriptor).first {
			return existing
		}

		let newMix = GasMix(
			name: name,
			oxygenPercent: oxygenPercent,
			heliumPercent: heliumPercent,
			argonPercent: argonPercent,
			hydrogenPercent: hydrogenPercent
		)
		if let uddfId { newMix.externalId = uddfId }
		context.insert(newMix)
		return newMix
	}

	/// Folds gas mixes that are copies of one another into a single record,
	/// returning how many duplicates were removed. Does not save.
	///
	/// With iCloud sync, `findOrCreate` running on two devices before their
	/// first sync can create the same mix twice. Mixes count as duplicates
	/// only when the name and every gas percentage match exactly, so two
	/// mixes the user deliberately named differently are left alone. As with
	/// `LogbookOwner.mergeDuplicates(in:)`, the survivor is the smallest
	/// `externalId` so devices merging concurrently converge on the same
	/// record. Tanks using a duplicate are moved to the survivor first.
	@discardableResult
	static func mergeDuplicates(in context: ModelContext) throws -> Int {
		let descriptor = FetchDescriptor<GasMix>(sortBy: [SortDescriptor(\.externalId)])
		var survivors: [DuplicateKey: GasMix] = [:]
		var removed = 0
		for mix in try context.fetch(descriptor) {
			let key = DuplicateKey(mix)
			guard let survivor = survivors[key] else {
				survivors[key] = mix
				continue
			}
			for tank in mix.tanks ?? [] {
				tank.gasMix = survivor
			}
			context.delete(mix)
			removed += 1
		}
		return removed
	}

	/// The fields that must all match for two mixes to count as duplicates.
	private struct DuplicateKey: Hashable {
		let name: String
		let oxygen: Double
		let helium: Double
		let argon: Double
		let hydrogen: Double

		init(_ mix: GasMix) {
			name = mix.name
			oxygen = mix.oxygenPercent
			helium = mix.heliumPercent
			argon = mix.argonPercent
			hydrogen = mix.hydrogenPercent
		}
	}
}
