//
//  UDDFRoundTripTests.swift
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

/// Full-loop tests: seed a database, export to UDDF, re-import into a fresh
/// database, and assert the key data survived the round trip.
@MainActor
@Suite(.tags(.importExport, .roundTrip))
struct UDDFRoundTripTests {

	@Test func diveSurvivesExportImportLoop() throws {
		let sourceContainer = try TestModelContainer.make()
		let sourceContext = sourceContainer.mainContext

		let site = DiveSite(name: "Palancar Reef", country: "Mexico", region: "Cozumel",
							latitude: 20.3005, longitude: -87.0196)
		sourceContext.insert(site)
		let dive = Dive(diveNumber: 142, date: Date(timeIntervalSince1970: 1_750_000_000),
						title: "Palancar Caves", maxDepthMeters: 28.4, durationSeconds: 3120,
						waterTempCelsius: 27.0, visibilityMeters: 25, rating: 5,
						importSource: "UDDF", site: site)
		sourceContext.insert(dive)
		try sourceContext.save()

		let xml = try UDDFExporter.exportString(from: sourceContext)

		// Re-import into a completely separate store.
		let destContainer = try TestModelContainer.make()
		let destContext = destContainer.mainContext
		let summary = try UDDFImporter.importData(Data(xml.utf8), into: destContext)
		#expect(summary.dives == 1)

		let restored = try #require(try destContext.fetch(FetchDescriptor<Dive>()).first)
		#expect(restored.externalId == dive.externalId)
		#expect(restored.diveNumber == 142)
		#expect(restored.maxDepthMeters == 28.4)
		#expect(restored.durationSeconds == 3120)
		#expect(restored.rating == 5)
		#expect(restored.site?.name == "Palancar Reef")
		#expect(restored.site?.country == "Mexico")
		// Wall-clock time preserved despite no timezone in the UDDF datetime.
		#expect(abs(restored.date.timeIntervalSince(dive.date)) < 1.0)
	}

	@Test func gasMixSurvivesRoundTrip() throws {
		let sourceContainer = try TestModelContainer.make()
		let sourceContext = sourceContainer.mainContext
		let gas = GasMix(name: "EAN32", oxygenPercent: 32)
		sourceContext.insert(gas)
		let dive = Dive(maxDepthMeters: 20, durationSeconds: 1200, importSource: "UDDF")
		sourceContext.insert(dive)
		let tank = Tank(gasMix: gas, startPressureBar: 200, endPressureBar: 50)
		tank.dive = dive
		sourceContext.insert(tank)
		try sourceContext.save()

		let xml = try UDDFExporter.exportString(from: sourceContext)
		let destContainer = try TestModelContainer.make()
		let destContext = destContainer.mainContext
		try UDDFImporter.importData(Data(xml.utf8), into: destContext)

		let restoredTank = try #require(try destContext.fetch(FetchDescriptor<Tank>()).first)
		#expect(restoredTank.gasMix?.oxygenPercent == 32)
		#expect(restoredTank.startPressureBar == 200)
		#expect(restoredTank.endPressureBar == 50)
	}

	@Test func equipmentUsedOnADiveSurvivesRoundTrip() throws {
		let sourceContainer = try TestModelContainer.make()
		let sourceContext = sourceContainer.mainContext

		let regulator = Equipment(name: "MK25 EVO", type: .regulator, manufacturer: "Scubapro")
		let mask = Equipment(name: "Frameless", type: .mask, manufacturer: "Cressi")
		sourceContext.insert(regulator)
		sourceContext.insert(mask)
		let dive = Dive(diveNumber: 9, maxDepthMeters: 22, durationSeconds: 2400, importSource: "UDDF")
		dive.equipment = [regulator, mask]
		sourceContext.insert(dive)
		try sourceContext.save()

		let xml = try UDDFExporter.exportString(from: sourceContext)
		let destContainer = try TestModelContainer.make()
		let destContext = destContainer.mainContext
		try UDDFImporter.importData(Data(xml.utf8), into: destContext)

		let restored = try #require(try destContext.fetch(FetchDescriptor<Dive>()).first)
		let restoredNames = Set((restored.equipment ?? []).map(\.name))
		#expect(restoredNames == ["MK25 EVO", "Frameless"])
	}

	/// Cameras are written as a nested `<body>` sub-piece, so the importer has to
	/// read their details from there or they come back nameless — and a nameless
	/// piece is dropped entirely.
	@Test func cameraEquipmentSurvivesRoundTrip() throws {
		let sourceContainer = try TestModelContainer.make()
		let sourceContext = sourceContainer.mainContext

		let camera = Equipment(name: "Nikon D600", type: .camera, manufacturer: "Nikon", model: "D600")
		let video = Equipment(name: "GoPro", type: .videoCamera, manufacturer: "GoPro", model: "Hero 12")
		sourceContext.insert(camera)
		sourceContext.insert(video)
		let dive = Dive(diveNumber: 1, maxDepthMeters: 18, durationSeconds: 2400, importSource: "UDDF")
		dive.equipment = [camera, video]
		sourceContext.insert(dive)
		try sourceContext.save()

		let xml = try UDDFExporter.exportString(from: sourceContext)
		let destContainer = try TestModelContainer.make()
		let destContext = destContainer.mainContext
		try UDDFImporter.importData(Data(xml.utf8), into: destContext)

		let restored = try destContext.fetch(FetchDescriptor<Equipment>())
		#expect(Set(restored.map(\.name)) == ["Nikon D600", "GoPro"])
		let restoredCamera = try #require(restored.first { $0.name == "Nikon D600" })
		#expect(restoredCamera.resolvedType == .camera)
		#expect(restoredCamera.manufacturer == "Nikon")
		#expect(restoredCamera.model == "D600")
		// And the dive still links to both pieces.
		let restoredDive = try #require(try destContext.fetch(FetchDescriptor<Dive>()).first)
		#expect((restoredDive.equipment ?? []).count == 2)
	}

	/// The schema-conformance changes all have to survive a round trip: prefixed
	/// ids, `<passedtime>`, `<leadquantity>`, `<pulserate>`, the nested
	/// manufacturer name, and country inside `<geography><address>`.
	@Test func schemaConformantFormsSurviveRoundTrip() throws {
		let sourceContainer = try TestModelContainer.make()
		let sourceContext = sourceContainer.mainContext

		let site = DiveSite(name: "Blue Corner", country: "Palau", region: "Koror")
		sourceContext.insert(site)
		let regulator = Equipment(name: "MK25 EVO", type: .regulator, manufacturer: "Scubapro")
		sourceContext.insert(regulator)
		let dive = Dive(diveNumber: 7, maxDepthMeters: 30, durationSeconds: 2700,
						weightKg: 6.5, importSource: "UDDF", site: site)
		dive.surfaceIntervalSeconds = 3600
		dive.equipment = [regulator]
		sourceContext.insert(dive)
		let sample = DepthSample(elapsedSeconds: 60, depthMeters: 12.5)
		sample.heartbeatBPM = 72
		sample.dive = dive
		sourceContext.insert(sample)
		try sourceContext.save()

		let xml = try UDDFExporter.exportString(from: sourceContext)
		let destContainer = try TestModelContainer.make()
		let destContext = destContainer.mainContext
		try UDDFImporter.importData(Data(xml.utf8), into: destContext)

		let restored = try #require(try destContext.fetch(FetchDescriptor<Dive>()).first)
		// The prefix is stripped, so identities are preserved.
		#expect(restored.externalId == dive.externalId)
		#expect(restored.surfaceIntervalSeconds == 3600)
		#expect(restored.weightKg == 6.5)
		#expect(restored.site?.externalId == site.externalId)
		#expect(restored.site?.country == "Palau")
		#expect(restored.site?.region == "Koror")
		#expect(restored.equipment?.first?.manufacturer == "Scubapro")
		#expect(restored.diveProfile?.first?.heartbeatBPM == 72)
	}
}
