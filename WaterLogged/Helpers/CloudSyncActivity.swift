//
//  CloudSyncActivity.swift
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

import Foundation

/// A running summary of iCloud sync activity, built from the CloudKit
/// container's setup/import/export events. `CloudSyncMonitor` feeds it; Settings
/// displays `summary`.
///
/// CloudKit posts each event twice, once when it starts (no end date) and once
/// when it finishes, under the same identifier. Pairing them by identifier
/// tells us what is in flight right now.
///
/// `nonisolated` because its values are built in `CloudSyncMonitor`'s
/// notification callback, which runs on CloudKit's private queue.
nonisolated struct CloudSyncActivity: Equatable, Sendable {

	/// What a CloudKit event was doing.
	enum Kind: Equatable {
		case setup
		case downloading
		case uploading
	}

	/// Why the most recent failed event failed, in user-facing terms.
	enum Issue: Equatable {
		case notSignedIn
		case storageFull
		case offline
		case other(String)

		var message: String {
			switch self {
				case .notSignedIn: "Not signed in to iCloud"
				case .storageFull: "iCloud storage is full"
				case .offline: "Waiting for a network connection"
				case .other(let description): description
			}
		}
	}

	/// What the Settings status row shows.
	enum Summary: Equatable {
		case waiting
		case settingUp
		case downloading
		case uploading
		case upToDate(Date)
		case failed(Issue)

		var text: String {
			switch self {
				case .waiting: "Waiting to sync"
				case .settingUp: "Setting up…"
				case .downloading: "Downloading…"
				case .uploading: "Uploading…"
				case .upToDate: "Up to date"
				case .failed(let issue): issue.message
			}
		}
	}

	private var inProgress: [UUID: Kind] = [:]
	private(set) var lastSuccess: Date?
	private(set) var lastIssue: Issue?

	/// Records one event notification.
	///
	/// - Returns: `true` when this notification is a download that just
	///   finished successfully, meaning the store may hold new records from
	///   another device.
	@discardableResult
	mutating func record(id: UUID, kind: Kind, endDate: Date?, succeeded: Bool, issue: Issue?) -> Bool {
		guard let endDate else {
			inProgress[id] = kind
			return false
		}
		inProgress[id] = nil
		if succeeded {
			lastSuccess = endDate
			lastIssue = nil
		} else {
			lastIssue = issue ?? .other("iCloud sync failed")
		}
		return succeeded && kind == .downloading
	}

	/// In-flight work takes priority (downloads first, since that's what the
	/// user is usually waiting on), then the last failure, then the last success.
	var summary: Summary {
		let active = Set(inProgress.values)
		if active.contains(.downloading) { return .downloading }
		if active.contains(.uploading) { return .uploading }
		if active.contains(.setup) { return .settingUp }
		if let lastIssue { return .failed(lastIssue) }
		if let lastSuccess { return .upToDate(lastSuccess) }
		return .waiting
	}
}
