//
//  BackupRoundTripTests.swift
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

/// Backup → wipe → restore fidelity across every model type, including media
/// bytes and the depth-sample optionals guarded by the faulting workaround.
@MainActor
@Suite(.tags(.backup, .roundTrip))
struct BackupRoundTripTests {

	private func fetchOne<T: PersistentModel>(
		_ type: T.Type,
		matching externalId: String,
		keyPath: KeyPath<T, String>,
		in context: ModelContext
	) throws -> T {
		let all = try context.fetch(FetchDescriptor<T>())
		return try #require(all.first { $0[keyPath: keyPath] == externalId })
	}

	@Test func fullLogbookSurvivesBackupAndRestore() throws {
		let sourceContainer = try TestModelContainer.make()
		let sourceContext = sourceContainer.mainContext
		let handles = try FullLogbook.seed(into: sourceContext)

		try withTemporaryDirectory { scratch in
			let zipURL = try BackupPackager.createExportArchive(from: sourceContext, workingDirectory: scratch)

			// Restore into a completely fresh store.
			let destContainer = try TestModelContainer.make()
			let destContext = destContainer.mainContext
			let restoreSummary = try RestorePackager.restoreArchive(
				at: zipURL, into: destContext, workingDirectory: scratch
			)
			#expect(restoreSummary.dives == 1)

			// Entity counts.
			let diveCount = try destContext.fetchCount(FetchDescriptor<Dive>())
			let siteCount = try destContext.fetchCount(FetchDescriptor<DiveSite>())
			let tripCount = try destContext.fetchCount(FetchDescriptor<Trip>())
			let buddyCount = try destContext.fetchCount(FetchDescriptor<Buddy>())
			let equipmentCount = try destContext.fetchCount(FetchDescriptor<Equipment>())
			let certCount = try destContext.fetchCount(FetchDescriptor<Certification>())
			#expect(diveCount == 1)
			#expect(siteCount == 1)
			#expect(tripCount == 1)
			#expect(buddyCount == 1)
			#expect(equipmentCount == 1)
			#expect(certCount == 1)

			// Dive scalar + relationship fidelity.
			let dive = try fetchOne(Dive.self, matching: handles.diveId, keyPath: \.externalId, in: destContext)
			#expect(dive.title == "Palancar Caves")
			#expect(dive.diveGuide == "Carlos")
			#expect(dive.diveOperator == "Scuba Club")
			#expect(dive.diveBoat == "Blue Boat")
			#expect(dive.waterType == .salt)
			#expect(dive.current == .slight)
			#expect(dive.suitType == .wetsuit3mm)
			#expect(dive.weightKg == 4.0)
			#expect(dive.tags.contains("reef"))
			#expect(dive.site?.externalId == handles.siteId)
			#expect(dive.trip?.externalId == handles.tripId)
			#expect(dive.equipment?.map(\.externalId) == [handles.equipmentId])

			// Depth-sample optionals — decoTTSSeconds only survives via the
			// faulting workaround in BackupPackager/UDDFExporter.
			let sample = try #require(dive.diveProfile?.first)
			#expect(sample.decoTTSSeconds == 90)
			#expect(sample.ppo2Bar == 0.42)

			// Equipment extras + service history.
			let equipment = try fetchOne(Equipment.self, matching: handles.equipmentId, keyPath: \.externalId, in: destContext)
			#expect(equipment.storeName == "Dive Shop")
			#expect(equipment.warranty == "2 years")
			#expect(equipment.autoAddToDives == true)
			#expect((equipment.serviceHistory?.count ?? 0) == 1)

			// Buddy retired flag.
			let buddy = try fetchOne(Buddy.self, matching: handles.buddyId, keyPath: \.externalId, in: destContext)
			#expect(buddy.isRetired == true)

			// Media fidelity: every @Attribute(.externalStorage) blob must come
			// back byte-for-byte, in the slot it started in. The payloads are
			// all distinct (see FullLogbook.Media), so bytes restored into the
			// wrong slot fail here rather than silently passing.
			#expect(dive.logbookImageData == FullLogbook.Media.logbookScan)
			#expect(dive.verificationSignatureData == FullLogbook.Media.signature)

			// The scan's original name rides along on <logbookimage originalfilename>.
			#expect(dive.logbookImageFilename == "logbook-page-142.png")
			#expect(equipment.photoData == FullLogbook.Media.equipmentPhoto)
			#expect(buddy.photoData == FullLogbook.Media.buddyPhoto)

			let cert = try fetchOne(Certification.self, matching: handles.certificationId,
									keyPath: \.externalId, in: destContext)
			#expect(cert.frontImageData == FullLogbook.Media.certFront)
			#expect(cert.backImageData == FullLogbook.Media.certBack)

			let restoredOwner = try LogbookOwner.fetchOrCreate(in: destContext)
			#expect(restoredOwner.photoData == FullLogbook.Media.ownerPhoto)

			let restoredPhoto = try #require(dive.photos?.first)
			#expect(restoredPhoto.imageData == FullLogbook.Media.divePhoto)
			#expect(restoredPhoto.caption == "Swimthrough")
			#expect(restoredPhoto.originalFilename == "IMG_0142.jpg")
		}
	}

	/// Regression test for a real bug: a tank logged with a gas mix but no
	/// starting pressure has no `<tankdata>` in the UDDF file (the schema
	/// requires `<tankpressurebegin>`), so without the extras.xml fallback in
	/// `BackupPackager.writeUnlinkedTanks` / `RestorePackager`, the tank — and
	/// with it the dive's spot in that gas mix's "related dives" — silently
	/// vanished on restore.
	@Test(.tags(.edgeCase)) func tankWithoutStartingPressurePreservesGasMixAssociationAfterRestore() throws {
		let sourceContainer = try TestModelContainer.make()
		let sourceContext = sourceContainer.mainContext

		let gas = GasMix(name: "EAN32", oxygenPercent: 32)
		sourceContext.insert(gas)
		let dive = Dive(maxDepthMeters: 20, durationSeconds: 1200, importSource: "UDDF")
		sourceContext.insert(dive)
		let diveId = dive.externalId
		// No starting pressure recorded, only the end reading.
		let tank = Tank(gasMix: gas, endPressureBar: 60)
		tank.dive = dive
		sourceContext.insert(tank)
		try sourceContext.save()

		try withTemporaryDirectory { scratch in
			let zipURL = try BackupPackager.createExportArchive(from: sourceContext, workingDirectory: scratch)

			let destContainer = try TestModelContainer.make()
			let destContext = destContainer.mainContext
			try RestorePackager.restoreArchive(at: zipURL, into: destContext, workingDirectory: scratch)

			let restoredDive = try fetchOne(Dive.self, matching: diveId, keyPath: \.externalId, in: destContext)
			let restoredTank = try #require(restoredDive.tanks?.first)
			#expect(restoredDive.tanks?.count == 1)
			#expect(restoredTank.gasMix?.oxygenPercent == 32)
			#expect(restoredTank.endPressureBar == 60)
			#expect(restoredTank.startPressureBar == nil)

			// The point of the fix: the gas mix's computed "related dives"
			// (GasMix.tanks -> Tank.dive) must include this dive.
			let restoredGasMix = try #require(try destContext.fetch(FetchDescriptor<GasMix>()).first)
			let relatedDiveIds = Set((restoredGasMix.tanks ?? []).compactMap { $0.dive?.externalId })
			#expect(relatedDiveIds == [diveId])
		}
	}

	/// Regression test for the companion bug: without `GasMix.findOrCreate`
	/// matching on `uddfId` first, a gas mix used by both a normally-exported
	/// tank (has starting pressure) and an extras-only tank (doesn't) could be
	/// recreated as two separate records on restore, splitting its dive history
	/// between them instead of just undercounting it.
	@Test(.tags(.edgeCase)) func sameGasMixAcrossDivesDoesNotFragmentOnRestore() throws {
		let sourceContainer = try TestModelContainer.make()
		let sourceContext = sourceContainer.mainContext

		let gas = GasMix(name: "EAN32", oxygenPercent: 32)
		sourceContext.insert(gas)

		let diveWithPressure = Dive(maxDepthMeters: 20, durationSeconds: 1200, importSource: "UDDF")
		sourceContext.insert(diveWithPressure)
		let diveWithPressureId = diveWithPressure.externalId
		let tankWithPressure = Tank(gasMix: gas, startPressureBar: 200, endPressureBar: 50)
		tankWithPressure.dive = diveWithPressure
		sourceContext.insert(tankWithPressure)

		let diveWithoutPressure = Dive(maxDepthMeters: 18, durationSeconds: 1800, importSource: "UDDF")
		sourceContext.insert(diveWithoutPressure)
		let diveWithoutPressureId = diveWithoutPressure.externalId
		let tankWithoutPressure = Tank(gasMix: gas, endPressureBar: 60)
		tankWithoutPressure.dive = diveWithoutPressure
		sourceContext.insert(tankWithoutPressure)

		try sourceContext.save()

		try withTemporaryDirectory { scratch in
			let zipURL = try BackupPackager.createExportArchive(from: sourceContext, workingDirectory: scratch)

			let destContainer = try TestModelContainer.make()
			let destContext = destContainer.mainContext
			try RestorePackager.restoreArchive(at: zipURL, into: destContext, workingDirectory: scratch)

			let restoredGasMixes = try destContext.fetch(FetchDescriptor<GasMix>())
			#expect(restoredGasMixes.count == 1)

			let restoredGasMix = try #require(restoredGasMixes.first)
			let relatedDiveIds = Set((restoredGasMix.tanks ?? []).compactMap { $0.dive?.externalId })
			#expect(relatedDiveIds == [diveWithPressureId, diveWithoutPressureId])
		}
	}
}
