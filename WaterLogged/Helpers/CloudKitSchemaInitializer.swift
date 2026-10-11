//
//  CloudKitSchemaInitializer.swift
//  WaterLogged
//
//  Created by John Meyer on 10/11/26.
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

#if DEBUG
import CoreData
import Foundation
import SwiftData

/// Debug-only tool that fills in the CloudKit **Development** schema before it's
/// deployed to Production.
///
/// CloudKit builds the Development schema on the fly from uploaded records, so a
/// field appears only once some record has had a value in it. Production can't
/// add fields by itself, so any field missing at deploy time would make that
/// record fail to sync for users. `initializeCloudKitSchema()` uploads one
/// sample record per type with every field filled in, then deletes the samples.
///
/// It runs only when the app is launched with the `-initializeCloudKitSchema`
/// argument (set it in the scheme's Run → Arguments), so it never runs by accident.
/// It uses a throwaway store in the temporary directory, never the real log book.
/// Add `-com.apple.CoreData.CloudKitDebug 1` alongside it to see Core Data's
/// "Successfully set up CloudKit integration" confirmation in the console.
///
/// This follows Apple's "Syncing model data across a person's devices →
/// Initialize the CloudKit development schema", and must run before the SwiftData
/// container is created so the two frameworks never mirror to CloudKit at once.
nonisolated enum CloudKitSchemaInitializer {

	/// The launch argument that turns the initializer on.
	static let launchArgument = "-initializeCloudKitSchema"

	/// Initializes the schema if the app was launched with `launchArgument`.
	/// Blocks the calling thread while the sample records upload; a Debug-only
	/// one-off, so that's acceptable. Errors are logged, never fatal.
	static func runIfRequested() {
		guard ProcessInfo.processInfo.arguments.contains(launchArgument) else { return }

		let directory = URL.temporaryDirectory.appending(path: "CloudKitSchemaInit-\(UUID().uuidString)")
		defer { try? FileManager.default.removeItem(at: directory) }

		print("CloudKitSchemaInitializer: initializing the CloudKit Development schema for \(WaterLoggedStore.cloudKitContainerIdentifier)…")
		do {
			// Core Data won't create the store's parent folder cleanly; without
			// this it logs a long sandbox/permissions report before recovering.
			try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

			// The autorelease pool makes sure the Core Data container is gone
			// before the SwiftData stack is set up.
			try autoreleasepool {
				try initializeSchema(storeURL: directory.appending(path: "SchemaInit.store"))
			}
			print("CloudKitSchemaInitializer: done. Check the record types in the CloudKit Console, then remove \(launchArgument) from the scheme.")
		} catch {
			print("CloudKitSchemaInitializer: FAILED: \(error)")
		}
	}

	/// Loads a throwaway CloudKit-mirrored store built from the app's model types,
	/// uploads the schema, and unloads the store again.
	private static func initializeSchema(storeURL: URL) throws {
		guard let model = NSManagedObjectModel.makeManagedObjectModel(for: WaterLoggedStore.modelTypes) else {
			throw InitializationError.couldNotBuildModel
		}

		let description = NSPersistentStoreDescription(url: storeURL)
		description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
			containerIdentifier: WaterLoggedStore.cloudKitContainerIdentifier
		)
		// Load synchronously so the store is ready before the schema upload starts.
		description.shouldAddStoreAsynchronously = false

		let container = NSPersistentCloudKitContainer(name: "SchemaInit", managedObjectModel: model)
		container.persistentStoreDescriptions = [description]

		let loadResult = LoadResult()
		container.loadPersistentStores { _, error in
			loadResult.error = error
		}
		if let error = loadResult.error {
			throw error
		}

		try container.initializeCloudKitSchema()

		// Unload the store so nothing keeps mirroring once SwiftData starts.
		// This cancels the background import CloudKit began when the store
		// loaded, so a "cancelled because the store was removed from the
		// coordinator" error (134407) follows in the console; it's expected.
		for store in container.persistentStoreCoordinator.persistentStores {
			try container.persistentStoreCoordinator.remove(store)
		}
	}

	/// Carries the store-load error out of `loadPersistentStores`'s callback,
	/// which runs synchronously because `shouldAddStoreAsynchronously` is false.
	private final class LoadResult: @unchecked Sendable {
		var error: (any Error)?
	}

	enum InitializationError: Error {
		case couldNotBuildModel
	}
}
#endif
