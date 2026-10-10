//
//  PersistenceFactoryTests.swift
//  WaterLoggedTests
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

import Testing
import Foundation
import SwiftData
@testable import WaterLogged

/// `findOrCreate` / `fetchOrCreate` factory helpers on the models.
@MainActor
@Suite
struct PersistenceFactoryTests {

	// `container` must be stored: a ModelContext does not retain its container.
	let container: ModelContainer
	let context: ModelContext

	init() throws {
		container = try TestModelContainer.make()
		context = container.mainContext
	}

	@Test func gasMixFindOrCreateReturnsExistingForMatchingPercentages() throws {
		let first = GasMix.findOrCreate(name: "EAN32", oxygenPercent: 32, in: context)
		try context.save()

		let second = GasMix.findOrCreate(name: "Nitrox", oxygenPercent: 32, in: context)
		let gasCount = try context.fetchCount(FetchDescriptor<GasMix>())
		#expect(first === second)
		#expect(gasCount == 1)
	}

	@Test func gasMixFindOrCreateCreatesNewForDifferentPercentages() throws {
		_ = GasMix.findOrCreate(name: "Air", oxygenPercent: 21, in: context)
		_ = GasMix.findOrCreate(name: "EAN32", oxygenPercent: 32, in: context)
		try context.save()
		let gasCount = try context.fetchCount(FetchDescriptor<GasMix>())
		#expect(gasCount == 2)
	}

	@Test func gasMixFindOrCreateDerivesNitrogenFromOxygen() throws {
		let mix = GasMix.findOrCreate(name: "EAN32", oxygenPercent: 32, in: context)
		try context.save()
		#expect(mix.nitrogenPercent == 68)
	}

	/// A restore's `uddfId` must win over a percentage match that lost precision
	/// round-tripping through UDDF's 6-decimal-digit string format — otherwise a
	/// single gas mix used across several dives could be recreated as two
	/// separate records, splitting its "related dives" between them.
	@Test func gasMixFindOrCreateMatchesByUddfIdEvenWithDriftedPercentage() throws {
		let created = GasMix.findOrCreate(
			name: "EAN32", oxygenPercent: 32, uddfId: "mix-1", in: context
		)
		try context.save()

		let refetched = GasMix.findOrCreate(
			name: "EAN32", oxygenPercent: 32.000000000000004, uddfId: "mix-1", in: context
		)
		let gasCount = try context.fetchCount(FetchDescriptor<GasMix>())
		#expect(created === refetched)
		#expect(gasCount == 1)
	}

	/// `uddfId` is only applied to a newly-created record (mirroring every other
	/// `findOrCreate`'s `uddfId` contract) — a percentage match against an
	/// existing record must never overwrite that record's externalId.
	@Test func gasMixFindOrCreateOnlySetsExternalIdOnNewRecords() throws {
		let created = GasMix.findOrCreate(name: "EAN32", oxygenPercent: 32, uddfId: "mix-1", in: context)
		#expect(created.externalId == "mix-1")
		try context.save()

		let matchedByPercentage = GasMix.findOrCreate(
			name: "EAN32", oxygenPercent: 32, uddfId: "mix-2", in: context
		)
		#expect(matchedByPercentage === created)
		#expect(matchedByPercentage.externalId == "mix-1")
	}

	/// Two devices each creating the same mix before their first iCloud sync
	/// must converge on one record, with every tank pointing at it.
	@Test func gasMixMergeDuplicatesFoldsIdenticalMixesIntoSmallestExternalId() throws {
		let survivor = GasMix(externalId: "A", name: "EAN32", oxygenPercent: 32)
		let duplicate = GasMix(externalId: "B", name: "EAN32", oxygenPercent: 32)
		let tank = Tank()
		context.insert(survivor)
		context.insert(duplicate)
		context.insert(tank)
		tank.gasMix = duplicate
		try context.save()

		let removed = try GasMix.mergeDuplicates(in: context)
		try context.save()

		let remaining = try context.fetch(FetchDescriptor<GasMix>())
		#expect(removed == 1)
		#expect(remaining.map(\.externalId) == ["A"])
		#expect(tank.gasMix === survivor)
	}

	/// Gas switches in a dive profile follow their mix to the survivor, so a
	/// sync merge doesn't drop them.
	@Test func gasMixMergeDuplicatesMovesGasSwitchesToSurvivor() throws {
		let survivor = GasMix(externalId: "A", name: "EAN32", oxygenPercent: 32)
		let duplicate = GasMix(externalId: "B", name: "EAN32", oxygenPercent: 32)
		context.insert(survivor)
		context.insert(duplicate)
		let sample = DepthSample(elapsedSeconds: 0, depthMeters: 5, activeGasMix: duplicate)
		context.insert(sample)
		try context.save()

		let removed = try GasMix.mergeDuplicates(in: context)
		try context.save()

		#expect(removed == 1)
		#expect(sample.activeGasMix === survivor)
	}

	/// Same gases under different names may be deliberate, so they're kept apart.
	@Test func gasMixMergeDuplicatesKeepsDifferentlyNamedMixes() throws {
		context.insert(GasMix(externalId: "A", name: "EAN32", oxygenPercent: 32))
		context.insert(GasMix(externalId: "B", name: "Deco 32", oxygenPercent: 32))
		context.insert(GasMix(externalId: "C", name: "EAN32", oxygenPercent: 36))
		try context.save()

		let removed = try GasMix.mergeDuplicates(in: context)
		let mixCount = try context.fetchCount(FetchDescriptor<GasMix>())
		#expect(removed == 0)
		#expect(mixCount == 3)
	}

	@Test func logbookOwnerFetchOrCreateIsSingleton() throws {
		let first = try LogbookOwner.fetchOrCreate(in: context)
		first.givenName = "Jane"
		try context.save()

		let second = try LogbookOwner.fetchOrCreate(in: context)
		let ownerCount = try context.fetchCount(FetchDescriptor<LogbookOwner>())
		#expect(first === second)
		#expect(second.givenName == "Jane")
		#expect(ownerCount == 1)
	}

	/// Two devices that each created an owner before their first iCloud sync
	/// must converge on one, keeping the details and certifications of both.
	@Test func logbookOwnerMergeDuplicatesFoldsIntoSmallestExternalId() throws {
		let survivor = LogbookOwner(externalId: "A", givenName: "Jane")
		let duplicate = LogbookOwner(externalId: "B", givenName: "Ignored", familyName: "Diver")
		let certification = Certification(name: "Open Water")
		context.insert(survivor)
		context.insert(duplicate)
		context.insert(certification)
		certification.owner = duplicate
		try context.save()

		let merged = try #require(try LogbookOwner.mergeDuplicates(in: context))
		try context.save()

		let ownerCount = try context.fetchCount(FetchDescriptor<LogbookOwner>())
		#expect(ownerCount == 1)
		#expect(merged.externalId == "A")
		#expect(merged.givenName == "Jane")
		#expect(merged.familyName == "Diver")
		#expect(certification.owner === merged)
	}

	@Test func logbookOwnerFetchOrCreateMergesDuplicates() throws {
		context.insert(LogbookOwner(externalId: "B"))
		context.insert(LogbookOwner(externalId: "A"))
		try context.save()

		let owner = try LogbookOwner.fetchOrCreate(in: context)
		try context.save()

		let ownerCount = try context.fetchCount(FetchDescriptor<LogbookOwner>())
		#expect(owner.externalId == "A")
		#expect(ownerCount == 1)
	}
}
