//
//  TestModelContainer.swift
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

import Foundation
import SwiftData
@testable import WaterLogged

/// Helpers for spinning up isolated, in-memory SwiftData stacks and scratch
/// directories for the import/export and backup/restore test suites.
///
/// Each call to `make()` returns a brand-new container backed only by memory,
/// so tests never share persistent state and can run in any order (the FIRST
/// principle of test hygiene). The schema mirrors production exactly by reusing
/// `WaterLoggedStore.schema`, so a container behaves identically to the app's.
enum TestModelContainer {

	/// Serializes container creation. Swift Testing runs suites in parallel, and
	/// concurrently spinning up SwiftData stacks races on shared CoreData model
	/// state and traps. Creation is cheap, so a lock here is harmless.
	private static let creationLock = NSLock()

	// ⚠️ CALLERS MUST KEEP THE RETURNED CONTAINER ALIVE.
	//
	// A `ModelContext` does NOT retain its `ModelContainer`. Writing
	//
	//     let context = try TestModelContainer.make().mainContext   // ✗ WRONG
	//
	// releases the container at the end of that expression and leaves the
	// context pointing at a deallocated store; the next fetch or save traps
	// inside SwiftData with `EXC_BREAKPOINT` and kills the whole test process
	// (taking every concurrently running test with it). Most of this target
	// once did exactly that, which is why nine suites sat disabled for weeks,
	// misdiagnosed as Xcode 27 beta instability.
	//
	// Correct forms:
	//
	//     let container = try TestModelContainer.make()             // ✓ stored property
	//     let context = container.mainContext
	//
	//     let (container, context) = try TestModelContainer.makeContext()  // ✓ both bound

	/// A fresh, empty, in-memory container using the full production schema.
	/// Each container gets a unique configuration name so its store is distinct.
	///
	/// The caller owns the returned container and must keep it alive for as long
	/// as any context derived from it is in use — see the warning above.
	static func make() throws -> ModelContainer {
		creationLock.lock()
		defer { creationLock.unlock() }
		// `cloudKitDatabase: .none` is essential. The default `.automatic` sees
		// the app's iCloud entitlement and starts CloudKit mirroring even on an
		// in-memory store; setup then fails, CloudKit pulls the store out from
		// under the context, and the next fetch aborts the whole test process
		// with "No eligible connection available".
		let configuration = ModelConfiguration(
			"WLTest-\(UUID().uuidString)",
			isStoredInMemoryOnly: true,
			cloudKitDatabase: .none
		)
		return try ModelContainer(for: WaterLoggedStore.schema, configurations: configuration)
	}

	/// A fresh in-memory container plus its main context, for convenience.
	static func makeContext() throws -> (ModelContainer, ModelContext) {
		let container = try make()
		return (container, container.mainContext)
	}
}

/// Runs `body` with a freshly created, unique temporary directory that is
/// removed afterwards regardless of whether the body throws. Used by the
/// filesystem-backed archive tests so they leave no residue behind.
func withTemporaryDirectory<T>(_ body: (URL) throws -> T) throws -> T {
	let directory = URL.temporaryDirectory.appending(path: "WLTests_\(UUID().uuidString)")
	try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
	defer { try? FileManager.default.removeItem(at: directory) }
	return try body(directory)
}
