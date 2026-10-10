//
//  OwnerSideEffectTests.swift
//  WaterLoggedTests
//
//  Created by John Meyer on 10/4/26.
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

/// Import, UDDF export and backup must only create a log book owner when they
/// actually have owner data to store — and the read-only paths must never
/// create, merge or delete owner records.
@MainActor
@Suite(.tags(.importExport))
struct OwnerSideEffectTests {

	private func ownerCount(_ container: ModelContainer) throws -> Int {
		try ModelContext(container).fetchCount(FetchDescriptor<LogbookOwner>())
	}

	/// A saved log book with one dive and no owner record.
	private func ownerlessLogbook() throws -> ModelContainer {
		let container = try TestModelContainer.make()
		container.mainContext.insert(Dive(title: "Solo", maxDepthMeters: 12, durationSeconds: 1_800))
		try container.mainContext.save()
		return container
	}

	@Test("Importing a file with no owner or certifications creates no owner", arguments: [
		"sitesOnly", "buddiesOnly", "equipmentOnly", "minimalDive"
	])
	func importWithoutOwnerData(_ fixture: String) throws {
		let xml = switch fixture {
			case "sitesOnly": UDDFFixtures.sitesOnly
			case "buddiesOnly": UDDFFixtures.buddiesOnly
			case "equipmentOnly": UDDFFixtures.equipmentOnly
			default: UDDFFixtures.minimalDive
		}
		let container = try TestModelContainer.make()
		try UDDFImporter.importData(Data(xml.utf8), into: container.mainContext)
		#expect(try ownerCount(container) == 0)
	}

	@Test func ownerWithDetailsIsStillImported() throws {
		let container = try TestModelContainer.make()
		let summary = try UDDFImporter.importData(Data(UDDFFixtures.ownerOnly.utf8), into: container.mainContext)
		#expect(summary.ownerImported)
		let owner = try #require(try ModelContext(container).fetch(FetchDescriptor<LogbookOwner>()).first)
		#expect(owner.givenName == "Jane")
	}

	@Test func emptyOwnerElementIsNotReportedAsADiverProfile() throws {
		// Equipment lives inside <owner>, so this file has an owner element but
		// no profile.
		let container = try TestModelContainer.make()
		let summary = try UDDFImporter.importData(Data(UDDFFixtures.equipmentOnly.utf8), into: container.mainContext)
		#expect(summary.ownerImported == false)
		#expect(summary.message == "Imported 1 equipment item.")
	}

	@Test func importedCertificationsStillBelongToAnOwner() throws {
		let container = try TestModelContainer.make()
		try UDDFImporter.importData(Data(UDDFFixtures.certificationsOnly.utf8), into: container.mainContext)
		let disk = ModelContext(container)
		#expect(try disk.fetchCount(FetchDescriptor<LogbookOwner>()) == 1)
		let cert = try #require(try disk.fetch(FetchDescriptor<Certification>()).first)
		#expect(cert.owner != nil)
	}

	@Test func uddfExportDoesNotCreateAnOwner() throws {
		let container = try ownerlessLogbook()
		let xml = try UDDFExporter.exportString(from: container.mainContext)
		try container.mainContext.save()
		#expect(try ownerCount(container) == 0)
		// With no owner, buddies, equipment or certifications there is nothing
		// for a <diver> section to hold, so none is written (rather than an
		// empty owner).
		#expect(xml.contains("<diver>") == false)
	}

	@Test func backupDoesNotCreateAnOwner() throws {
		let container = try ownerlessLogbook()
		try withTemporaryDirectory { scratch in
			_ = try BackupPackager.createExportArchive(from: container.mainContext, workingDirectory: scratch)
		}
		try container.mainContext.save()
		#expect(try ownerCount(container) == 0)
	}

	@Test func exportAndBackupLeaveDuplicateOwnersAlone() throws {
		let container = try TestModelContainer.make()
		let context = container.mainContext
		context.insert(Dive(title: "Solo", maxDepthMeters: 12, durationSeconds: 1_800))
		context.insert(LogbookOwner(externalId: "a-owner", givenName: "Jane"))
		context.insert(LogbookOwner(externalId: "b-owner", familyName: "Diver"))
		try context.save()

		let xml = try UDDFExporter.exportString(from: context)
		try withTemporaryDirectory { scratch in
			_ = try BackupPackager.createExportArchive(from: context, workingDirectory: scratch)
		}
		try context.save()

		// Merging duplicates is the launch-time and owner-screen job, not export's.
		#expect(try ownerCount(container) == 2)
		// Export uses the record a merge would keep: the smallest externalId.
		#expect(xml.contains(UDDFIdentifier.xmlID(for: "a-owner")))
		#expect(xml.contains("<firstname>Jane</firstname>"))
	}
}
