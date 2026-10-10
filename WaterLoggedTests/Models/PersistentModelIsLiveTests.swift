//
//  PersistentModelIsLiveTests.swift
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

/// `isLive` is what list rows and detail screens check before reading a model.
/// A view can still be holding a record after a restore replaces the log book;
/// that record reports `isDeleted == false` but has lost its context, and
/// reading it then traps (seen on the simulator, 2026-10-04).
@MainActor
@Suite(.tags(.backup))
struct PersistentModelIsLiveTests {

	@Test func savedModelIsLive() throws {
		let container = try TestModelContainer.make()
		let dive = Dive(title: "Live", maxDepthMeters: 10, durationSeconds: 600)
		container.mainContext.insert(dive)
		try container.mainContext.save()
		#expect(dive.isLive)
	}

	@Test func deletedModelIsNotLive() throws {
		let container = try TestModelContainer.make()
		let context = container.mainContext
		let dive = Dive(title: "Gone", maxDepthMeters: 10, durationSeconds: 600)
		context.insert(dive)
		try context.save()

		context.delete(dive)
		#expect(dive.isLive == false)      // pending deletion
		try context.save()
		#expect(dive.isLive == false)      // deletion saved
	}

	@Test func recordHeldAcrossARestoreIsNotLive() throws {
		let container = try TestModelContainer.make()
		let context = container.mainContext
		let held = Dive(title: "Held by a view", maxDepthMeters: 10, durationSeconds: 600)
		context.insert(held)
		try context.save()

		let archive = RawZip.make([.init(name: "logbook.uddf", data: Data(UDDFFixtures.minimalDive.utf8))])
		try withTemporaryDirectory { scratch in
			let url = scratch.appending(path: "archive.zip")
			try archive.write(to: url)
			try RestorePackager.restoreArchive(at: url, into: context, workingDirectory: scratch)
		}

		// The old record isn't flagged as deleted — only the lost context gives
		// it away, which is why `isLive` checks both.
		#expect(held.isDeleted == false)
		#expect(held.isLive == false)
		let restored = try #require(try context.fetch(FetchDescriptor<Dive>()).first)
		#expect(restored.isLive)
	}
}
