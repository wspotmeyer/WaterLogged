//
//  UDDFImportMappingTests.swift
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

/// Tests that drive `UDDFImporter.importData` into an in-memory context and
/// assert the resulting SwiftData models and the returned `ImportSummary`.
@MainActor
@Suite(.tags(.importExport))
struct UDDFImportMappingTests {

	let container: ModelContainer
	let context: ModelContext

	init() throws {
		container = try TestModelContainer.make()
		context = container.mainContext
		// Deterministic saves: import tests either save explicitly (shouldSave:
		// true) or assert that nothing was persisted (shouldSave: false).
		context.autosaveEnabled = false
	}

	@discardableResult
	private func importFixture(_ xml: String) throws -> UDDFImporter.ImportSummary {
		try UDDFImporter.importData(Data(xml.utf8), into: context)
	}

	private func count<T: PersistentModel>(_ type: T.Type) throws -> Int {
		try context.fetchCount(FetchDescriptor<T>())
	}

	// MARK: - Dive mapping

	@Test func minimalDiveInsertsOneDive() throws {
		let summary = try importFixture(UDDFFixtures.minimalDive)
		let diveCount = try count(Dive.self)
		#expect(summary.dives == 1)
		#expect(diveCount == 1)

		let dive = try #require(try context.fetch(FetchDescriptor<Dive>()).first)
		#expect(dive.externalId == "dive-1")
		#expect(dive.maxDepthMeters == 18.5)
		#expect(dive.durationSeconds == 2400)
		#expect(dive.importSource == "UDDF")
	}

	@Test func richDiveMapsRelationshipsAndSamples() throws {
		let summary = try importFixture(UDDFFixtures.richDive)
		#expect(summary.dives == 1)

		let dive = try #require(try context.fetch(FetchDescriptor<Dive>()).first)
		#expect(dive.site?.name == "Palancar Reef")
		#expect(dive.buddies?.count == 1)
		#expect(dive.tanks?.count == 1)
		#expect(dive.tanks?.first?.gasMix?.oxygenPercent == 32)
		#expect(dive.diveProfile?.count == 2)

		// The deep waypoint's no-deco time becomes a .noDecoLimit sample.
		let ndlSample = dive.diveProfile?.first { $0.decoStatus == .noDecoLimit }
		#expect(ndlSample?.decoTimeSeconds == 1200)
	}

	// MARK: - Summary counts for dive-less files

	@Test func sitesOnlySummary() throws {
		let summary = try importFixture(UDDFFixtures.sitesOnly)
		#expect(summary.dives == 0)
		#expect(summary.sites == 1)
		let siteCount = try count(DiveSite.self)
		#expect(summary.total == 1)
		#expect(siteCount == 1)
	}

	@Test func buddiesOnlySummary() throws {
		let summary = try importFixture(UDDFFixtures.buddiesOnly)
		let buddyCount = try count(Buddy.self)
		#expect(summary.buddies == 2)
		#expect(buddyCount == 2)
	}

	@Test func equipmentOnlySummary() throws {
		let summary = try importFixture(UDDFFixtures.equipmentOnly)
		#expect(summary.equipment == 1)
		let item = try #require(try context.fetch(FetchDescriptor<Equipment>()).first)
		#expect(item.serialNumber == "SN-12345")
		#expect(item.resolvedType == .regulator)
	}

	@Test func certificationsOnlySummary() throws {
		let summary = try importFixture(UDDFFixtures.certificationsOnly)
		#expect(summary.certifications == 1)
		let cert = try #require(try context.fetch(FetchDescriptor<Certification>()).first)
		#expect(cert.issuingAgency == "PADI")
		#expect(cert.name.localizedStandardContains("Advanced Open Water"))
		#expect(cert.instructorName == "Maria Lopez")
	}

	@Test func ownerOnlyImports() throws {
		let summary = try importFixture(UDDFFixtures.ownerOnly)
		#expect(summary.ownerImported == true)
		let owner = try #require(try context.fetch(FetchDescriptor<LogbookOwner>()).first)
		#expect(owner.givenName == "Jane")
		#expect(owner.email == "jane@example.com")
	}

	@Test func tripLinksToDive() throws {
		let summary = try importFixture(UDDFFixtures.tripWithDive)
		#expect(summary.trips == 1)
		#expect(summary.dives == 1)
		let dive = try #require(try context.fetch(FetchDescriptor<Dive>()).first)
		#expect(dive.trip?.name == "Cozumel Spring Trip")
	}

	// MARK: - Idempotency / duplicate matching

	@Test(.tags(.edgeCase)) func reimportingSameFileMatchesRatherThanDuplicates() throws {
		try importFixture(UDDFFixtures.richDive)
		try importFixture(UDDFFixtures.richDive)

		// Two dives (dives are not de-duplicated), but sites/buddies/gases match.
		let dives = try count(Dive.self)
		let sites = try count(DiveSite.self)
		let buddies = try count(Buddy.self)
		let gases = try count(GasMix.self)
		#expect(dives == 2)
		#expect(sites == 1)
		#expect(buddies == 1)
		#expect(gases == 1)
	}

	// MARK: - shouldSave

	@Test func shouldSaveFalseDoesNotPersistToStore() throws {
		_ = try UDDFImporter.importData(Data(UDDFFixtures.minimalDive.utf8), into: context, shouldSave: false)

		// Visible in this context (uncommitted), but not persisted to the store,
		// so a second independent context sees nothing.
		let localCount = try count(Dive.self)
		#expect(localCount == 1)

		let otherContext = ModelContext(container)
		let otherCount = try otherContext.fetchCount(FetchDescriptor<Dive>())
		#expect(otherCount == 0)
	}
}
