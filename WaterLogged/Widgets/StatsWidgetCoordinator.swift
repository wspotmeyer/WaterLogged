//
//  StatsWidgetCoordinator.swift
//  WaterLogged
//
//  Created by John Meyer on 6/28/26.
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
import WidgetKit

/// Keeps the home-screen statistics widget in sync with the logbook by writing a
/// fresh `StatsSnapshot` to the shared App Group store whenever the data
/// changes, then asking WidgetKit to reload its timelines.
///
/// Modeled on `SpotlightIndexCoordinator`: it observes `ModelContext.didSave`
/// (which fires for every context backed by the shared container, including the
/// background contexts used by import and restore) and debounces so a burst of
/// saves — e.g. a bulk import — collapses into a single rebuild.
@MainActor
final class StatsWidgetCoordinator {
	static let shared = StatsWidgetCoordinator()
	private init() {}

	private var started = false
	private var observer: (any NSObjectProtocol)?
	private var flushTask: Task<Void, Never>?

	/// How long to wait after the last save before rebuilding, so rapid
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
		) { [weak self] _ in
			Task { @MainActor [weak self] in
				self?.scheduleRefresh()
			}
		}
	}

	/// Rebuilds and writes the snapshot immediately. Call at launch (and when the
	/// app returns to the foreground, to pick up unit-system changes made in
	/// the app's Settings screen).
	func refreshNow() {
		flushTask?.cancel()
		writeSnapshot()
	}

	/// Rebuilds after iCloud downloads changes from another device, which
	/// doesn't post `ModelContext.didSave`. Debounced like a save.
	func refreshForSyncedChanges() {
		scheduleRefresh()
	}

	private func scheduleRefresh() {
		flushTask?.cancel()
		flushTask = Task { [weak self] in
			try? await Task.sleep(for: self?.debounce ?? .milliseconds(750))
			guard !Task.isCancelled, let self else { return }
			self.writeSnapshot()
		}
	}

	/// Fetches the current dives and trips, builds a snapshot in the user's unit
	/// system, persists it to the App Group, and reloads the widget timelines.
	private func writeSnapshot() {
		let context = WaterLoggedStore.shared.mainContext
		let dives = (try? context.fetch(FetchDescriptor<Dive>())) ?? []
		let trips = (try? context.fetch(FetchDescriptor<Trip>())) ?? []

		let snapshot = StatsSnapshotBuilder.makeSnapshot(
			dives: dives,
			trips: trips,
			priorHistory: .current,
			unitSystem: WaterLoggedStore.preferredUnitSystem,
			updatedAt: Date()
		)
		snapshot.save()
		WidgetCenter.shared.reloadAllTimelines()
	}
}
