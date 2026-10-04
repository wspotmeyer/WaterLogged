//
//  BackupPackagerTests.swift
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
@Suite(.tags(.backup))
struct BackupPackagerTests {

	/// Recursively lists the file URLs under a directory.
	private func fileURLs(under directory: URL) -> [URL] {
		guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else {
			return []
		}
		return enumerator.compactMap { $0 as? URL }
	}

	/// Recursively lists the file names (last path components) under a directory.
	private func fileNames(under directory: URL) -> [String] {
		fileURLs(under: directory).map(\.lastPathComponent)
	}


	@Test func archiveContainsCoreDocuments() throws {
		let container = try TestModelContainer.make()
		let context = container.mainContext
		try FullLogbook.seed(into: context)

		try withTemporaryDirectory { scratch in
			let zipURL = try BackupPackager.createExportArchive(from: context, workingDirectory: scratch)
			#expect(FileManager.default.fileExists(atPath: zipURL.path()))

			// Extract and inspect the archive contents.
			let out = scratch.appending(path: "extracted")
			try ZipReader.extractArchive(at: zipURL, to: out)
			let names = fileNames(under: out)

			#expect(names.contains("logbook.uddf"))
			#expect(names.contains("extras.xml"))
		}
	}

	/// Every `@Attribute(.externalStorage)` blob in the fixture must be written
	/// into `media/`, with the file extension `ImageFileHelper` infers from the
	/// payload's magic bytes.
	@Test func mediaBlobsAreExportedToTheArchive() throws {
		let container = try TestModelContainer.make()
		let context = container.mainContext
		try FullLogbook.seed(into: context)

		try withTemporaryDirectory { scratch in
			let zipURL = try BackupPackager.createExportArchive(from: context, workingDirectory: scratch)
			let out = scratch.appending(path: "extracted")
			try ZipReader.extractArchive(at: zipURL, to: out)

			// Locate media/ by walking the tree rather than assuming where the
			// archive root sits.
			let mediaURLs = fileURLs(under: out)
				.filter { $0.deletingLastPathComponent().lastPathComponent == "media" }
			let mediaFiles = mediaURLs.map(\.lastPathComponent)

			// 8 seeded blobs: dive photo, logbook scan, signature, equipment,
			// buddy, cert front, cert back, owner.
			#expect(mediaFiles.count == 8)

			// Prefixes identify the owning entity; extensions come from the
			// magic bytes, so a mis-detected type shows up here.
			#expect(mediaFiles.contains { $0.hasPrefix("photo") && $0.hasSuffix(".jpg") })
			#expect(mediaFiles.contains { $0.hasPrefix("logbook") && $0.hasSuffix(".png") })
			#expect(mediaFiles.contains { $0.hasPrefix("signature") && $0.hasSuffix(".gif") })
			#expect(mediaFiles.contains { $0.hasPrefix("equipment") && $0.hasSuffix(".tiff") })
			#expect(mediaFiles.contains { $0.hasPrefix("buddy") && $0.hasSuffix(".tiff") })
			#expect(mediaFiles.contains { $0.hasPrefix("cert_front") && $0.hasSuffix(".heic") })
			#expect(mediaFiles.contains { $0.hasPrefix("cert_back") && $0.hasSuffix(".jpg") })

			// Bytes on disk must match what was seeded.
			let logbookURL = try #require(mediaURLs.first { $0.lastPathComponent.hasPrefix("logbook") })
			let written = try Data(contentsOf: logbookURL)
			#expect(written == FullLogbook.Media.logbookScan)
		}
	}

	@Test func extrasReferencesModelExternalIds() throws {
		let container = try TestModelContainer.make()
		let context = container.mainContext
		let handles = try FullLogbook.seed(into: context)

		try withTemporaryDirectory { scratch in
			let zipURL = try BackupPackager.createExportArchive(from: context, workingDirectory: scratch)
			let out = scratch.appending(path: "extracted")
			try ZipReader.extractArchive(at: zipURL, to: out)

			let extrasURL = try #require(
				fileURLs(under: out)
					.first { $0.lastPathComponent == "extras.xml" }
			)
			let extras = try String(contentsOf: extrasURL, encoding: .utf8)
			#expect(extras.contains(handles.diveId))
			#expect(extras.contains(handles.equipmentId))
			#expect(extras.contains(handles.buddyId))
			// The dive → equipment association now lives in the UDDF file as
			// <equipmentused>, not in extras.
			#expect(extras.contains("<equipmentused>") == false)

			let logbookURL = try #require(
				fileURLs(under: out)
					.first { $0.lastPathComponent == "logbook.uddf" }
			)
			let uddf = try String(contentsOf: logbookURL, encoding: .utf8)
			#expect(uddf.contains("<equipmentused>"))
			#expect(uddf.contains("<link ref=\"\(UDDFIdentifier.xmlID(for: handles.equipmentId))\"/>"))
		}
	}

	/// UDDF's `tankdataType` requires `<tankpressurebegin>`, so a tank logged with
	/// a gas mix but no starting pressure gets no `<tankdata>` (and hence no
	/// `<link>` to its gas mix) in `logbook.uddf`. `writeUnlinkedTanks` records
	/// that association in extras.xml instead, so restore can still recreate it.
	@Test func tankWithoutStartingPressureIsRecordedInExtras() throws {
		let container = try TestModelContainer.make()
		let context = container.mainContext

		let gas = GasMix(name: "EAN32", oxygenPercent: 32)
		context.insert(gas)
		let dive = Dive(maxDepthMeters: 20, durationSeconds: 1200, importSource: "UDDF")
		context.insert(dive)
		let tank = Tank(gasMix: gas, endPressureBar: 60)
		tank.dive = dive
		context.insert(tank)
		try context.save()

		try withTemporaryDirectory { scratch in
			let zipURL = try BackupPackager.createExportArchive(from: context, workingDirectory: scratch)
			let out = scratch.appending(path: "extracted")
			try ZipReader.extractArchive(at: zipURL, to: out)

			let extrasURL = try #require(
				fileURLs(under: out)
					.first { $0.lastPathComponent == "extras.xml" }
			)
			let extras = try String(contentsOf: extrasURL, encoding: .utf8)
			#expect(extras.contains("<tanks>"))
			#expect(extras.contains(gas.externalId))
			#expect(extras.contains("<tankpressureend>60</tankpressureend>"))

			// The UDDF file itself has no <tankdata> for this tank: no starting
			// pressure means the schema can't represent it there.
			let logbookURL = try #require(
				fileURLs(under: out)
					.first { $0.lastPathComponent == "logbook.uddf" }
			)
			let uddf = try String(contentsOf: logbookURL, encoding: .utf8)
			#expect(uddf.contains("<tankdata>") == false)
		}
	}

}
