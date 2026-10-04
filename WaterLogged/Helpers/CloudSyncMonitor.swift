//
//  CloudSyncMonitor.swift
//  WaterLogged
//
//  Created by John Meyer on 10/3/26.
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

import CloudKit
import CoreData
import Foundation

/// Watches the CloudKit sync engine underneath SwiftData and publishes what
/// it's doing, for the Settings status row, and when it has downloaded
/// changes from another device.
///
/// SwiftData syncs through `NSPersistentCloudKitContainer`, which posts
/// `eventChangedNotification` as setup, import, and export operations start
/// and finish. Records arriving this way don't post `ModelContext.didSave`,
/// so this is also how the app learns that a download needs Spotlight, the
/// widget, and the duplicate merge to run.
@MainActor
@Observable
final class CloudSyncMonitor {
	static let shared = CloudSyncMonitor()
	private init() {}

	/// The current sync state. Only changes once `start(onDownload:)` has run.
	private(set) var activity = CloudSyncActivity()

	@ObservationIgnored private var observer: (any NSObjectProtocol)?
	@ObservationIgnored private var onDownload: (@MainActor () -> Void)?

	/// Begins observing sync events. Idempotent. Safe to call when sync is
	/// off, because CloudKit then posts no events.
	///
	/// - Parameter onDownload: Runs after each successful download from iCloud.
	func start(onDownload: @escaping @MainActor () -> Void) {
		guard observer == nil else { return }
		self.onDownload = onDownload

		observer = NotificationCenter.default.addObserver(
			forName: NSPersistentCloudKitContainer.eventChangedNotification,
			object: nil,
			queue: nil
		) { [weak self] notification in
			// Posted on CloudKit's private queue. `Event` isn't Sendable, so copy
			// out the plain values before hopping to the main actor.
			guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
					as? NSPersistentCloudKitContainer.Event else { return }
			let id = event.identifier
			let kind = Self.kind(of: event.type)
			let endDate = event.endDate
			let succeeded = event.succeeded
			let issue = Self.issue(for: event.error)
			Task { @MainActor [weak self] in
				self?.record(id: id, kind: kind, endDate: endDate, succeeded: succeeded, issue: issue)
			}
		}
	}

	private func record(
		id: UUID,
		kind: CloudSyncActivity.Kind,
		endDate: Date?,
		succeeded: Bool,
		issue: CloudSyncActivity.Issue?
	) {
		let downloaded = activity.record(id: id, kind: kind, endDate: endDate, succeeded: succeeded, issue: issue)
		if downloaded {
			onDownload?()
		}
	}

	nonisolated private static func kind(of type: NSPersistentCloudKitContainer.EventType) -> CloudSyncActivity.Kind {
		switch type {
			case .setup: .setup
			case .import: .downloading
			case .export: .uploading
			@unknown default: .setup
		}
	}

	/// Translates the CloudKit errors a user can do something about; anything
	/// else falls back to the system's description.
	nonisolated private static func issue(for error: (any Error)?) -> CloudSyncActivity.Issue? {
		guard let error else { return nil }
		if let cloudKitError = error as? CKError {
			switch cloudKitError.code {
				case .notAuthenticated:
					return .notSignedIn
				case .quotaExceeded:
					return .storageFull
				case .networkUnavailable, .networkFailure:
					return .offline
				default:
					break
			}
		}
		return .other(error.localizedDescription)
	}
}
