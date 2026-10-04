//
//  UDDFExporterTests.swift
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

/// Tests that build models in an in-memory context and assert on the UDDF XML
/// string produced by `UDDFExporter.exportString`, with no filesystem I/O.
@MainActor
@Suite(.tags(.importExport))
struct UDDFExporterTests {

	let container: ModelContainer
	let context: ModelContext

	init() throws {
		container = try TestModelContainer.make()
		context = container.mainContext
	}

	@Test func emptyDatabaseThrowsNoData() throws {
		let error = #expect(throws: UDDFExporter.ExportError.self) {
			_ = try UDDFExporter.exportString(from: context)
		}
		#expect(error == .noData)
	}

	@Test func exportsWellFormedHeaderAndDive() throws {
		let dive = Dive(diveNumber: 7, maxDepthMeters: 30.0, durationSeconds: 1800)
		context.insert(dive)
		try context.save()

		let xml = try UDDFExporter.exportString(from: context)
		#expect(xml.hasPrefix("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
		#expect(xml.contains("<uddf"))
		#expect(xml.contains("version=\"3.2.2\""))
		#expect(xml.contains("<generator>"))
		// The dive's externalId is used as its XML id, prefixed so it is a valid
		// xs:ID, which is what enables cross-referencing.
		#expect(xml.contains("<dive id=\"\(UDDFIdentifier.xmlID(for: dive.externalId))\">"))
		#expect(xml.contains("<greatestdepth>30</greatestdepth>"))
		#expect(xml.contains("<diveduration>1800</diveduration>"))
	}

	@Test func waterTemperatureConvertsCelsiusToKelvin() throws {
		let dive = Dive(maxDepthMeters: 20, durationSeconds: 1200, waterTempCelsius: 20.0)
		context.insert(dive)
		try context.save()

		let xml = try UDDFExporter.exportString(from: context)
		// 20°C + 273.15 = 293.15 K.
		#expect(xml.contains("<lowesttemperature>293.15</lowesttemperature>"))
	}

	@Test func sitesOnlySelectionContainsOnlySites() throws {
		let site = DiveSite(name: "Blue Corner", country: "Palau", latitude: 7.1513, longitude: 134.3627)
		context.insert(site)
		context.insert(Dive(diveNumber: 1, maxDepthMeters: 30, durationSeconds: 1800))
		try context.save()

		let xml = try UDDFExporter.exportString(from: context, selecting: [.diveSites])
		#expect(xml.contains("<divesite>"))
		#expect(xml.contains("<name>Blue Corner</name>"))
		#expect(xml.contains("<country>Palau</country>"))
		// No dives, and no <diver> section, in a sites-only export.
		#expect(xml.contains("<profiledata>") == false)
		#expect(xml.contains("<diver>") == false)
	}

	@Test func sitesOnlySelectionWithNoSitesThrowsNoData() throws {
		context.insert(Dive(diveNumber: 1, maxDepthMeters: 30, durationSeconds: 1800))
		try context.save()

		let error = #expect(throws: UDDFExporter.ExportError.self) {
			_ = try UDDFExporter.exportString(from: context, selecting: [.diveSites])
		}
		#expect(error == .noData)
	}

	@Test func emptySelectionThrowsNoData() throws {
		context.insert(Dive(diveNumber: 1, maxDepthMeters: 30, durationSeconds: 1800))
		try context.save()

		let error = #expect(throws: UDDFExporter.ExportError.self) {
			_ = try UDDFExporter.exportString(from: context, selecting: [])
		}
		#expect(error == .noData)
	}

	@Test func excludingSitesDropsTheDiveSiteLink() throws {
		let site = DiveSite(name: "Blue Corner")
		let dive = Dive(diveNumber: 3, maxDepthMeters: 25, durationSeconds: 2400)
		dive.site = site
		context.insert(site)
		context.insert(dive)
		try context.save()

		let xml = try UDDFExporter.exportString(from: context, selecting: [.dives])
		#expect(xml.contains("<dive id=\"\(UDDFIdentifier.xmlID(for: dive.externalId))\">"))
		#expect(xml.contains("<divesite>") == false)
		// The link to the excluded site is omitted rather than left dangling.
		#expect(xml.contains(site.externalId) == false)
	}

	@Test func buddiesOnlySelectionWritesDiverSection() throws {
		context.insert(Buddy(givenName: "Ada", familyName: "Lovelace"))
		context.insert(Dive(diveNumber: 1, maxDepthMeters: 30, durationSeconds: 1800))
		try context.save()

		let xml = try UDDFExporter.exportString(from: context, selecting: [.buddies])
		#expect(xml.contains("<diver>"))
		#expect(xml.contains("<lastname>Lovelace</lastname>"))
		#expect(xml.contains("<profiledata>") == false)
	}

	@Test func equipmentUsedLinksTheDiveToItsGear() throws {
		let regulator = Equipment(name: "MK25 EVO", type: .regulator)
		let dive = Dive(diveNumber: 4, maxDepthMeters: 18, durationSeconds: 2000)
		dive.equipment = [regulator]
		context.insert(regulator)
		context.insert(dive)
		try context.save()

		let xml = try UDDFExporter.exportString(from: context)
		#expect(xml.contains("<equipmentused>"))
		// The link is an IDREF pointing at the exported <regulator id="…"> item.
		#expect(xml.contains("<link ref=\"\(UDDFIdentifier.xmlID(for: regulator.externalId))\"/>"))
		#expect(try informationBeforeDive(in: xml).contains("<equipmentused>"))
	}

	@Test func equipmentUsedIsOmittedWhenEquipmentIsNotExported() throws {
		let regulator = Equipment(name: "MK25 EVO", type: .regulator)
		let dive = Dive(diveNumber: 4, maxDepthMeters: 18, durationSeconds: 2000)
		dive.equipment = [regulator]
		context.insert(regulator)
		context.insert(dive)
		try context.save()

		// Without the equipment itself in the file, a link would be a dangling IDREF.
		let xml = try UDDFExporter.exportString(from: context, selecting: [.dives])
		#expect(xml.contains("<equipmentused>") == false)
		#expect(xml.contains(regulator.externalId) == false)
	}

	/// `informationbeforediveType` is an `xs:sequence`, so children must appear
	/// in schema order: link, divenumber, datetime, airtemperature,
	/// surfaceintervalbeforedive, equipmentused.
	@Test func informationBeforeDiveChildrenFollowSchemaOrder() throws {
		let site = DiveSite(name: "Blue Corner")
		let buddy = Buddy(givenName: "Ada", familyName: "Lovelace")
		let regulator = Equipment(name: "MK25 EVO", type: .regulator)
		let dive = Dive(diveNumber: 12, maxDepthMeters: 30, durationSeconds: 2700,
						airTempCelsius: 24, site: site)
		dive.surfaceIntervalSeconds = 3600
		dive.buddies = [buddy]
		dive.equipment = [regulator]
		context.insert(site)
		context.insert(buddy)
		context.insert(regulator)
		context.insert(dive)
		try context.save()

		let block = try informationBeforeDive(in: try UDDFExporter.exportString(from: context))
		var cursor = block.startIndex
		for tag in ["<link", "<divenumber>", "<datetime>", "<airtemperature>",
					"<surfaceintervalbeforedive>", "<equipmentused>"] {
			let found = try #require(block.range(of: tag, range: cursor..<block.endIndex),
									 "\(tag) is missing or out of schema order")
			cursor = found.upperBound
		}
	}

	/// Every `id` and `ref` must be an XML NCName, which rules out the raw UUIDs
	/// in `externalId` — they start with a digit more often than not.
	@Test func identifiersAreValidNCNames() throws {
		let site = DiveSite(name: "Blue Corner", country: "Palau")
		let dive = Dive(diveNumber: 1, maxDepthMeters: 10, durationSeconds: 600)
		dive.site = site
		// An externalId that starts with a digit is what breaks a bare UUID.
		site.externalId = "9DA37680-97E3-461D-890F-F605AD0C0567"
		context.insert(site)
		context.insert(dive)
		try context.save()

		let xml = try UDDFExporter.exportString(from: context)
		for value in try attributeValues(named: "id", in: xml) + attributeValues(named: "ref", in: xml) {
			let first = try #require(value.first)
			#expect(first.isLetter || first == "_", "id/ref \"\(value)\" is not a valid NCName")
		}
		// And the transform is reversible, so the round trip keeps the identity.
		#expect(UDDFIdentifier.externalId(from: UDDFIdentifier.xmlID(for: site.externalId)) == site.externalId)
	}

	/// `equipmentType` is an `xs:sequence` of per-kind elements, so items must be
	/// grouped by kind and the kinds must appear in the schema's declared order.
	@Test func equipmentIsGroupedByKindInSchemaOrder() throws {
		context.insert(Equipment(name: "MK25 EVO", type: .regulator))
		context.insert(Equipment(name: "Frameless", type: .mask))
		context.insert(Equipment(name: "G260", type: .regulator))
		context.insert(Dive(diveNumber: 1, maxDepthMeters: 10, durationSeconds: 600))
		try context.save()

		let xml = try UDDFExporter.exportString(from: context)
		let maskIndex = try #require(xml.range(of: "<mask ")).lowerBound
		let firstRegulator = try #require(xml.range(of: "<regulator ")).lowerBound
		let lastRegulator = try #require(xml.range(of: "<regulator ", options: .backwards)).lowerBound
		// mask precedes regulator, and both regulators sit together after it.
		#expect(maskIndex < firstRegulator)
		#expect(firstRegulator < lastRegulator)
		#expect(xml.range(of: "<mask ", options: .backwards)?.lowerBound == maskIndex)
	}

	/// `cameraType` and `videocameraType` extend `ID_TYPE`, not
	/// `equipmentPieceType`, so they carry no name/manufacturer/model of their
	/// own — those belong to a nested sub-piece.
	@Test func cameraDetailsAreNestedInASubPiece() throws {
		let camera = Equipment(name: "Nikon D600", type: .camera, manufacturer: "Nikon", model: "D600")
		context.insert(camera)
		context.insert(Equipment(name: "GoPro", type: .videoCamera, manufacturer: "GoPro"))
		context.insert(Dive(diveNumber: 1, maxDepthMeters: 10, durationSeconds: 600))
		try context.save()

		let xml = try UDDFExporter.exportString(from: context)
		let cameraId = UDDFIdentifier.xmlID(for: camera.externalId)
		#expect(xml.contains("<camera id=\"\(cameraId)\">"))
		#expect(xml.contains("<body id=\"\(cameraId)-body\">"))
		#expect(xml.contains("<videocamera "))

		// The name must be inside <body>, never directly under <camera>.
		let start = try #require(xml.range(of: "<camera "))
		let end = try #require(xml.range(of: "</camera>"))
		let block = String(xml[start.upperBound..<end.lowerBound])
		let bodyStart = try #require(block.range(of: "<body "))
		#expect(block.range(of: "<name>")!.lowerBound > bodyStart.lowerBound)
	}

	@Test func surfaceIntervalIsWrappedInPassedTime() throws {
		let dive = Dive(diveNumber: 1, maxDepthMeters: 10, durationSeconds: 600)
		dive.surfaceIntervalSeconds = 3600
		context.insert(dive)
		try context.save()

		// surfaceintervalType is element-only, so bare seconds would be invalid.
		let xml = try UDDFExporter.exportString(from: context)
		#expect(xml.contains("<surfaceintervalbeforedive>"))
		#expect(xml.contains("<passedtime>3600</passedtime>"))
	}

	@Test func weightIsWrittenAsLeadQuantity() throws {
		let dive = Dive(diveNumber: 1, maxDepthMeters: 10, durationSeconds: 600, weightKg: 6.5)
		context.insert(dive)
		try context.save()

		let xml = try UDDFExporter.exportString(from: context)
		#expect(xml.contains("<equipmentused>"))
		#expect(xml.contains("<leadquantity>6.5</leadquantity>"))
	}

	/// `waypointType` is an `xs:sequence`: depth precedes divetime, the heart rate
	/// element is `pulserate`, and `setpo2` needs a `setby` attribute.
	@Test func waypointChildrenFollowSchemaOrder() throws {
		let dive = Dive(diveNumber: 1, maxDepthMeters: 30, durationSeconds: 1800)
		context.insert(dive)
		let sample = DepthSample(elapsedSeconds: 60, depthMeters: 12.5, waterTempCelsius: 20,
								 tankPressureBar: 180, ppo2Bar: 0.42)
		sample.cnsPercent = 3
		sample.setpointBar = 1.2
		sample.heartbeatBPM = 72
		sample.dive = dive
		context.insert(sample)
		try context.save()

		let xml = try UDDFExporter.exportString(from: context)
		let start = try #require(xml.range(of: "<waypoint>"))
		let end = try #require(xml.range(of: "</waypoint>"))
		let waypoint = String(xml[start.upperBound..<end.lowerBound])

		var cursor = waypoint.startIndex
		for tag in ["<cns>", "<depth>", "<divetime>", "<pulserate>", "<setpo2 ",
					"<tankpressure>", "<temperature>", "<measuredpo2>"] {
			let found = try #require(waypoint.range(of: tag, range: cursor..<waypoint.endIndex),
									 "\(tag) is missing or out of schema order")
			cursor = found.upperBound
		}
		#expect(waypoint.contains("<setpo2 setby=\"computer\">"))
		#expect(waypoint.contains("<heartrate>") == false)
	}

	/// `decostop` requires kind, decodepth and duration, and kind is limited to
	/// `safety` or `mandatory`.
	@Test func decoStopUsesSchemaKindsAndRequiredAttributes() throws {
		let dive = Dive(diveNumber: 1, maxDepthMeters: 30, durationSeconds: 1800)
		context.insert(dive)
		let stop = DepthSample(elapsedSeconds: 120, depthMeters: 6)
		stop.decoStatus = .decoStop
		stop.decoDepthMeters = 5
		stop.decoTimeSeconds = 180
		stop.dive = dive
		// A deco stop missing its depth cannot be written at all.
		let incomplete = DepthSample(elapsedSeconds: 180, depthMeters: 5)
		incomplete.decoStatus = .decoStop
		incomplete.dive = dive
		context.insert(stop)
		context.insert(incomplete)
		try context.save()

		let xml = try UDDFExporter.exportString(from: context)
		#expect(xml.contains("<decostop kind=\"mandatory\" decodepth=\"5\" duration=\"180\"/>"))
		#expect(xml.contains("kind=\"deco\"") == false)
		// Only the complete stop is emitted.
		#expect(xml.components(separatedBy: "<decostop").count - 1 == 1)
	}

	/// A safety stop must survive export as `kind="safety"`. It previously
	/// exported as `mandatory`, because any value other than the literal
	/// "safety" was treated as a mandatory stop.
	@Test func safetyStopExportsAsSafetyKind() throws {
		let dive = Dive(diveNumber: 1, maxDepthMeters: 30, durationSeconds: 1800)
		context.insert(dive)
		let stop = DepthSample(elapsedSeconds: 120, depthMeters: 5)
		stop.decoStatus = .safetyStop
		stop.decoDepthMeters = 5
		stop.decoTimeSeconds = 180
		stop.dive = dive
		context.insert(stop)
		try context.save()

		let xml = try UDDFExporter.exportString(from: context)
		#expect(xml.contains("<decostop kind=\"safety\""))
		#expect(xml.contains("kind=\"mandatory\"") == false)
	}

	/// A deep stop has no UDDF kind of its own, but it is still a stop the
	/// computer asked for, so it exports as mandatory rather than vanishing.
	@Test func deepStopExportsAsMandatoryKind() throws {
		let dive = Dive(diveNumber: 1, maxDepthMeters: 40, durationSeconds: 1800)
		context.insert(dive)
		let stop = DepthSample(elapsedSeconds: 300, depthMeters: 20)
		stop.decoStatus = .deepStop
		stop.decoDepthMeters = 20
		stop.decoTimeSeconds = 60
		stop.dive = dive
		context.insert(stop)
		try context.save()

		let xml = try UDDFExporter.exportString(from: context)
		#expect(xml.contains("<decostop kind=\"mandatory\" decodepth=\"20\" duration=\"60\"/>"))
	}

	/// An NDL sample reports remaining no-deco time, not a stop, so it must
	/// write `<nodecotime>` and no `<decostop>` element at all.
	@Test func noDecoLimitSampleWritesNoDecoTimeAndNoStop() throws {
		let dive = Dive(diveNumber: 1, maxDepthMeters: 18, durationSeconds: 1800)
		context.insert(dive)
		let sample = DepthSample(elapsedSeconds: 60, depthMeters: 18)
		sample.decoStatus = .noDecoLimit
		sample.decoTimeSeconds = 1200
		// A depth is present, so only the deco *kind* can keep the stop out.
		sample.decoDepthMeters = 18
		sample.dive = dive
		context.insert(sample)
		try context.save()

		let xml = try UDDFExporter.exportString(from: context)
		#expect(xml.contains("<nodecotime>1200</nodecotime>"))
		#expect(xml.contains("<decostop") == false)
	}

	@Test func certificationWritesLevelOnlyAndNoIdentifier() throws {
		let cert = Certification(name: "Rescue Diver — Nitrox", issuingAgency: "PADI",
								 instructorName: "Grace Hopper")
		context.insert(cert)
		try context.save()

		let xml = try UDDFExporter.exportString(from: context)
		// certificationType takes no id, and level/specialty are a choice.
		#expect(xml.contains("<certification>"))
		#expect(xml.contains("<level>Rescue Diver — Nitrox</level>"))
		#expect(xml.contains("<specialty>") == false)
		#expect(xml.contains("<organization>PADI</organization>"))
		#expect(xml.contains("<organisation>") == false)
		// instructorType extends individualType: an id plus <personal>.
		#expect(xml.contains("<instructor id="))
		#expect(xml.contains("<lastname>Hopper</lastname>"))
	}

	@Test func siteGeographyNestsCountryInAnAddress() throws {
		context.insert(DiveSite(name: "Blue Corner", country: "Palau", region: "Koror"))
		try context.save()

		let xml = try UDDFExporter.exportString(from: context, selecting: [.diveSites])
		// geographyType requires <location> and has no <country> of its own.
		#expect(xml.contains("<location>Blue Corner</location>"))
		#expect(xml.contains("<address>"))
		#expect(xml.contains("<country>Palau</country>"))
		#expect(xml.contains("<province>Koror</province>"))
	}

	/// Every `id`/`ref` attribute value in the document.
	private func attributeValues(named name: String, in xml: String) throws -> [String] {
		xml.split(separator: "\n").compactMap { line in
			guard let range = line.range(of: "\(name)=\"") else { return nil }
			let rest = line[range.upperBound...]
			guard let close = rest.firstIndex(of: "\"") else { return nil }
			return String(rest[..<close])
		}
	}

	/// The contents of the first `<informationbeforedive>` element.
	private func informationBeforeDive(in xml: String) throws -> String {
		let start = try #require(xml.range(of: "<informationbeforedive>"))
		let end = try #require(xml.range(of: "</informationbeforedive>"))
		return String(xml[start.upperBound..<end.lowerBound])
	}

	@Test func notesWithBlankLinesBecomeSeparateParagraphs() throws {
		let dive = Dive(maxDepthMeters: 12, durationSeconds: 600, notes: "First.\n\nThird.")
		context.insert(dive)
		try context.save()

		let xml = try UDDFExporter.exportString(from: context)
		#expect(xml.contains("<para>First.</para>"))
		#expect(xml.contains("<para></para>"))
		#expect(xml.contains("<para>Third.</para>"))
	}
}

/// Tests for the export tool's selection model, which decides what the user can
/// export and what the resulting file is called.
@Suite(.tags(.importExport))
struct UDDFExportSelectionTests {

	@Test func allSelectionCoversEveryCategory() {
		#expect(UDDFExportSelection.all.count == UDDFExportCategory.allCases.count)
		for category in UDDFExportCategory.allCases {
			#expect(UDDFExportSelection.all.contains(category))
		}
	}

	@Test func singleCategorySelectionNamesTheFileAfterIt() {
		#expect(UDDFExportSelection([.diveSites]).suggestedFileName == "WaterLogged Dive Sites")
		#expect(UDDFExportSelection([.dives]).suggestedFileName == "WaterLogged Dives")
	}

	@Test func broaderSelectionsUseTheGenericFileName() {
		#expect(UDDFExportSelection.all.suggestedFileName == "WaterLogged Logbook")
		#expect(UDDFExportSelection([.dives, .diveSites]).suggestedFileName == "WaterLogged Logbook")
		#expect(UDDFExportSelection().suggestedFileName == "WaterLogged Logbook")
	}

	@Test func countsOnlyReportSelectedCategories() {
		let counts = UDDFExportCounts(dives: 4, diveSites: 2, trips: 1)

		#expect(counts.total(for: [.dives]) == 4)
		#expect(counts.total(for: [.dives, .trips]) == 5)
		#expect(counts.total(for: .all) == 7)
		#expect(counts[.buddies] == 0)
	}

	@Test func selectingOnlyEmptyCategoriesLeavesNothingToExport() {
		let counts = UDDFExportCounts(dives: 4)

		#expect(counts.hasContent(for: [.dives]))
		#expect(counts.hasContent(for: [.buddies, .equipment]) == false)
		#expect(counts.hasContent(for: []) == false)
	}
}
