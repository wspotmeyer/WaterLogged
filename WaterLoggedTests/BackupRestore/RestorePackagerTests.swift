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
}
