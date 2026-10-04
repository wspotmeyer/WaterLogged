//
//  SpotlightIndexCoordinator.swift
//  WaterLogged
//
//  Created by John Meyer on 6/17/26.
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

import Foundation
import SwiftData

/// Keeps the Spotlight / Apple Intelligence index in sync with the SwiftData
/// store by reindexing whenever a save commits. This is what makes an edit to a
/// dive, site, or buddy show up in search and the assistant right away, rather
/// than only at the next launch.
///
/// It observes `ModelContext.didSave` (which fires for every context backed by
/// the shared container, including the background contexts used by import and
/// restore) and debounces the work so a burst of saves — e.g. a bulk import —
/// collapses into a single reindex. Saves that include deletions trigger a
/// purge-then-reindex so removed items leave the index too; pure inserts/edits
/// just re-donate the current entities (an upsert with no empty-index window).
@MainActor
final class SpotlightIndexCoordinator {
	static let shared = SpotlightIndexCoordinator()
	private init() {}

	private var started = false
	private var observer: (any NSObjectProtocol)?
	private var flushTask: Task<Void, Never>?
	private var pendingPurge = false

	/// How long to wait after the last save before reindexing, so rapid
	/// consecutive saves coalesce into one pass.
	private let debounce: Duration = .milliseconds(750)

	/// Begins observing saves. Idempotent — safe to call on every launch.
	func start() {
		guard !started else { return }
		started = true

		observer = NotificationCenter.default.addObserver(
			forName: ModelContext.didSave,
			object: nil,
			queue: nil
		) { [weak self] notification in
			// The notification can post on a background context's thread, so
			// pull the only value we need (whether anything was deleted) out
			// synchronously before hopping to the main actor — `userInfo` isn't
			// Sendable and mustn't cross the boundary.
			let hadDeletions = Self.notificationHasDeletions(notification)
			Task { @MainActor [weak self] in
				self?.scheduleReindex(purge: hadDeletions)
			}
		}
	}

	/// Reindexes after iCloud downloads changes from another device, which
	/// doesn't post `ModelContext.didSave`. Always purges, since we can't tell
	/// whether the download included deletions. Debounced like a save, so a
	/// burst of downloads during the first sync collapses into one pass.
	func refreshForSyncedChanges() {
		scheduleReindex(purge: true)
	}

	private func scheduleReindex(purge: Bool) {
		pendingPurge = pendingPurge || purge
		flushTask?.cancel()
		flushTask = Task { [weak self] in
			try? await Task.sleep(for: self?.debounce ?? .milliseconds(750))
			guard !Task.isCancelled, let self else { return }
			let shouldPurge = self.pendingPurge
			self.pendingPurge = false
			await self.reindex(purge: shouldPurge)
		}
	}

	private func reindex(purge: Bool) async {
		do {
			if purge {
				try await SpotlightIndexer.purgeAll()
			}
			try await SpotlightIndexer.indexAll()
		} catch {
			// Best-effort: a failed reindex shouldn't disrupt the app. The next
			// save — or the next launch — will try again.
		}
	}

	/// Whether a save's change set removed any models, in which case the index
	/// needs a purge so deleted items don't linger in search results.
	nonisolated private static func notificationHasDeletions(_ notification: Notification) -> Bool {
		guard let info = notification.userInfo else { return false }
		if let deleted = info[ModelContext.NotificationKey.deletedIdentifiers] as? Set<PersistentIdentifier>,
		   !deleted.isEmpty {
			return true
		}
		if let invalidated = info[ModelContext.NotificationKey.invalidatedAllIdentifiers] as? Set<PersistentIdentifier>,
		   !invalidated.isEmpty {
			return true
		}
		return false
	}
}
