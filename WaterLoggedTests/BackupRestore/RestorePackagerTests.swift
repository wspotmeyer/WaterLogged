//
//  RestorePackagerTests.swift
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

@MainActor
@Suite(.tags(.backup, .malformedInput))
struct RestorePackagerTests {

	/// Writes archive bytes to a temp file inside `scratch` and returns the URL.
	private func writeArchive(_ data: Data, in scratch: URL) throws -> URL {
		let url = scratch.appending(path: "archive.zip")
		try data.write(to: url)
		return url
	}

	@Test func missingLogbookThrowsArchiveInvalid() throws {
		let container = try TestModelContainer.make()
		let context = container.mainContext
		// A pre-existing dive that must survive a failed restore.
		context.insert(Dive(title: "Keep me", maxDepthMeters: 10, durationSeconds: 600))
		try context.save()

		let archive = RawZip.make([.init(name: "readme.txt", data: Data("not a backup".utf8))])

		try withTemporaryDirectory { scratch in
			let url = try writeArchive(archive, in: scratch)
			let error = #expect(throws: RestorePackager.RestoreError.self) {
				try RestorePackager.restoreArchive(at: url, into: context, workingDirectory: scratch)
			}
			if case .archiveInvalid = error {
				// expected
			} else {
				Issue.record("Expected .archiveInvalid, got \(String(describing: error))")
			}
			// Atomicity: the existing dive is untouched.
			let diveCount = try context.fetchCount(FetchDescriptor<Dive>())
			#expect(diveCount == 1)
		}
	}

	@Test func corruptExtrasThrowsImportFailedAndPreservesData() throws {
		let container = try TestModelContainer.make()
		let context = container.mainContext
		context.insert(Dive(title: "Keep me", maxDepthMeters: 10, durationSeconds: 600))
		try context.save()

		// Flat archive: a valid UDDF plus a malformed extras.xml. The restorer
		// pre-parses extras BEFORE deleting anything, so the failure must leave
		// the existing data intact.
		let archive = RawZip.make([
			.init(name: "logbook.uddf", data: Data(UDDFFixtures.minimalDive.utf8)),
			.init(name: "extras.xml", data: Data("<waterlogged-extras><oops".utf8))
		])

		try withTemporaryDirectory { scratch in
			let url = try writeArchive(archive, in: scratch)
			let error = #expect(throws: RestorePackager.RestoreError.self) {
				try RestorePackager.restoreArchive(at: url, into: context, workingDirectory: scratch)
			}
			if case .importFailed = error {
				// expected
			} else {
				Issue.record("Expected .importFailed, got \(String(describing: error))")
			}
			let dives = try context.fetch(FetchDescriptor<Dive>())
			#expect(dives.count == 1)
			#expect(dives.first?.title == "Keep me")
		}
	}

	@Test(.tags(.roundTrip)) func flatArchiveWithoutExtrasRestoresDive() throws {
		// A flat (non-nested) archive containing only a valid UDDF restores fine.
		let archive = RawZip.make([
			.init(name: "logbook.uddf", data: Data(UDDFFixtures.minimalDive.utf8))
		])

		let container = try TestModelContainer.make()
		let context = container.mainContext
		try withTemporaryDirectory { scratch in
			let url = try writeArchive(archive, in: scratch)
			let restored = try RestorePackager.restoreArchive(at: url, into: context, workingDirectory: scratch)
			#expect(restored.dives == 1)
			let diveCount = try context.fetchCount(FetchDescriptor<Dive>())
			#expect(diveCount == 1)
		}
	}

	@Test func restoreReplacesExistingData() throws {
		let container = try TestModelContainer.make()
		let context = container.mainContext
		// Pre-existing data that a successful restore should wipe.
		for i in 0..<3 {
			context.insert(Dive(title: "Old \(i)", maxDepthMeters: 5, durationSeconds: 300))
		}
		try context.save()

		let archive = RawZip.make([
			.init(name: "logbook.uddf", data: Data(UDDFFixtures.minimalDive.utf8))
		])
		try withTemporaryDirectory { scratch in
			let url = try writeArchive(archive, in: scratch)
			try RestorePackager.restoreArchive(at: url, into: context, workingDirectory: scratch)
			// Old dives gone, replaced by the single archived dive.
			let dives = try context.fetch(FetchDescriptor<Dive>())
			#expect(dives.count == 1)
			#expect(dives.first?.externalId == "dive-1")
		}
	}

	// MARK: - Atomicity on disk
	//
	// These read the store through a fresh ModelContext — what the next launch
	// would see — so a deletion that was already saved can't hide behind the
	// test's own context.

	/// Seeds one dive that a failed restore must leave on disk.
	private func seedKeeper(in context: ModelContext) throws {
		context.insert(Dive(title: "Keep me", maxDepthMeters: 10, durationSeconds: 600))
		try context.save()
	}

	private func divesOnDisk(_ container: ModelContainer) throws -> [Dive] {
		try ModelContext(container).fetch(FetchDescriptor<Dive>())
	}

	@Test("A malformed logbook.uddf fails without touching the existing logbook")
	func malformedLogbookPreservesDataOnDisk() throws {
		for logbook in [UDDFFixtures.truncated, UDDFFixtures.unclosedTag, "not xml at all"] {
			let container = try TestModelContainer.make()
			let context = container.mainContext
			try seedKeeper(in: context)

			let archive = RawZip.make([.init(name: "logbook.uddf", data: Data(logbook.utf8))])
			try withTemporaryDirectory { scratch in
				let url = try writeArchive(archive, in: scratch)
				#expect(throws: (any Error).self) {
					try RestorePackager.restoreArchive(at: url, into: context, workingDirectory: scratch)
				}
				let dives = try divesOnDisk(container)
				#expect(dives.count == 1)
				#expect(dives.first?.title == "Keep me")
				// The live context agrees: nothing is left pending.
				#expect(try context.fetchCount(FetchDescriptor<Dive>()) == 1)
				#expect(context.hasChanges == false)
			}
		}
	}

	@Test func failureAfterDeletingRollsBackEverything() throws {
		let container = try TestModelContainer.make()
		let context = container.mainContext
		try seedKeeper(in: context)

		// Parses fine but holds nothing importable, so the import step throws
		// after the existing data has been marked for deletion.
		let archive = RawZip.make([
			.init(name: "logbook.uddf", data: Data(UDDFFixtures.emptyDocument.utf8))
		])
		try withTemporaryDirectory { scratch in
			let url = try writeArchive(archive, in: scratch)
			#expect(throws: UDDFImporter.ImportError.self) {
				try RestorePackager.restoreArchive(at: url, into: context, workingDirectory: scratch)
			}
			let dives = try divesOnDisk(container)
			#expect(dives.count == 1)
			#expect(dives.first?.title == "Keep me")
			#expect(context.hasChanges == false)
		}
	}

	@Test func successfulRestoreReplacesDataOnDisk() throws {
		let container = try TestModelContainer.make()
		let context = container.mainContext
		try seedKeeper(in: context)

		let archive = RawZip.make([
			.init(name: "logbook.uddf", data: Data(UDDFFixtures.minimalDive.utf8))
		])
		try withTemporaryDirectory { scratch in
			let url = try writeArchive(archive, in: scratch)
			try RestorePackager.restoreArchive(at: url, into: context, workingDirectory: scratch)
			let dives = try divesOnDisk(container)
			#expect(dives.map(\.externalId) == ["dive-1"])
		}
	}

	@Test(.tags(.roundTrip)) func restoringTwiceIntoTheSameStoreKeepsOneCopyOfEverything() throws {
		let source = try TestModelContainer.make()
		_ = try FullLogbook.seed(into: source.mainContext)
		let dest = try TestModelContainer.make()

		try withTemporaryDirectory { scratch in
			let zip = try BackupPackager.createExportArchive(from: source.mainContext, workingDirectory: scratch)
			for _ in 0..<2 {
				try RestorePackager.restoreArchive(at: zip, into: dest.mainContext, workingDirectory: scratch)
			}
			// Old and restored records briefly coexist in one transaction with the
			// same externalIds; the importer must never reuse a record that is
			// pending deletion.
			let disk = ModelContext(dest)
			#expect(try disk.fetchCount(FetchDescriptor<Dive>()) == 1)
			#expect(try disk.fetchCount(FetchDescriptor<DiveSite>()) == 1)
			#expect(try disk.fetchCount(FetchDescriptor<Trip>()) == 1)
			#expect(try disk.fetchCount(FetchDescriptor<Buddy>()) == 1)
			#expect(try disk.fetchCount(FetchDescriptor<Equipment>()) == 1)
			#expect(try disk.fetchCount(FetchDescriptor<GasMix>()) == 1)
			#expect(try disk.fetchCount(FetchDescriptor<Certification>()) == 1)
			#expect(try disk.fetchCount(FetchDescriptor<LogbookOwner>()) == 1)
			#expect(try disk.fetchCount(FetchDescriptor<DepthSample>()) == 1)
			#expect(try disk.fetchCount(FetchDescriptor<Tank>()) == 1)
			#expect(try disk.fetchCount(FetchDescriptor<Photo>()) == 1)
			#expect(try disk.fetchCount(FetchDescriptor<ServiceRecord>()) == 1)
			let dive = try #require(try disk.fetch(FetchDescriptor<Dive>()).first)
			#expect(dive.site != nil)
			#expect(dive.trip != nil)
			#expect(dive.equipment?.count == 1)
			#expect(dive.tanks?.first?.gasMix != nil)
		}
	}
}
