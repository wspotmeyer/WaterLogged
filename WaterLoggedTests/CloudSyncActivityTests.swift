//
//  CloudSyncActivityTests.swift
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
import Testing
@testable import WaterLogged

/// The Settings sync status, derived from paired start/end CloudKit events.
@Suite
struct CloudSyncActivityTests {

	private let finish = Date(timeIntervalSince1970: 1_000)

	@Test func waitingBeforeAnyEvents() {
		#expect(CloudSyncActivity().summary == .waiting)
	}

	@Test func inFlightDownloadShowsDownloading() {
		var activity = CloudSyncActivity()
		activity.record(id: UUID(), kind: .downloading, endDate: nil, succeeded: false, issue: nil)
		#expect(activity.summary == .downloading)
	}

	@Test func downloadTakesPriorityOverConcurrentUpload() {
		var activity = CloudSyncActivity()
		activity.record(id: UUID(), kind: .uploading, endDate: nil, succeeded: false, issue: nil)
		activity.record(id: UUID(), kind: .downloading, endDate: nil, succeeded: false, issue: nil)
		#expect(activity.summary == .downloading)
	}

	@Test func finishedEventClearsItsStartAndReportsUpToDate() {
		var activity = CloudSyncActivity()
		let id = UUID()
		activity.record(id: id, kind: .uploading, endDate: nil, succeeded: false, issue: nil)
		activity.record(id: id, kind: .uploading, endDate: finish, succeeded: true, issue: nil)
		#expect(activity.summary == .upToDate(finish))
	}

	@Test func failureIsReportedUntilTheNextSuccess() {
		var activity = CloudSyncActivity()
		activity.record(id: UUID(), kind: .uploading, endDate: finish, succeeded: false, issue: .storageFull)
		#expect(activity.summary == .failed(.storageFull))

		activity.record(id: UUID(), kind: .uploading, endDate: finish, succeeded: true, issue: nil)
		#expect(activity.summary == .upToDate(finish))
	}

	@Test func failureWithoutAnIssueStillReportsAFailure() {
		var activity = CloudSyncActivity()
		activity.record(id: UUID(), kind: .downloading, endDate: finish, succeeded: false, issue: nil)
		#expect(activity.summary == .failed(.other("iCloud sync failed")))
	}

	/// Only a finished, successful download means records from another device
	/// may have arrived, which is what triggers the refresh and merge.
	@Test func onlyASuccessfulFinishedDownloadSignalsNewRecords() {
		var activity = CloudSyncActivity()
		let started = activity.record(id: UUID(), kind: .downloading, endDate: nil, succeeded: false, issue: nil)
		let failed = activity.record(id: UUID(), kind: .downloading, endDate: finish, succeeded: false, issue: .offline)
		let uploaded = activity.record(id: UUID(), kind: .uploading, endDate: finish, succeeded: true, issue: nil)
		let downloaded = activity.record(id: UUID(), kind: .downloading, endDate: finish, succeeded: true, issue: nil)
		#expect(!started)
		#expect(!failed)
		#expect(!uploaded)
		#expect(downloaded)
	}
}
