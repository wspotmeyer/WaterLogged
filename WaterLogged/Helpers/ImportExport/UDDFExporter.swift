//
//  UDDFExporter.swift
//  WaterLogged
//
//  Created by John Meyer on 4/26/26.
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

/// Exports the complete WaterLogged logbook as a UDDF 3.2.2 XML file.
///
/// UDDF uses SI units internally:
/// - Depth: meters
/// - Temperature: Kelvin
/// - Pressure: Pascals
/// - Time: seconds
/// - Gas fractions: 0.0–1.0
///
/// All XML `id` attributes use the model's `externalId` (UUID) to enable
/// cross-referencing with the companion extras XML.
struct UDDFExporter {

	/// The XML `id` attribute of every record written to the file, keyed by its
	/// SwiftData identifier, so `<link ref="…">` elements can be resolved while
	/// writing. A record missing from a map was not exported, and links to it
	/// are skipped rather than left dangling.
	private struct XMLIdMaps {
		var dives: [PersistentIdentifier: String] = [:]
		var sites: [PersistentIdentifier: String] = [:]
		var gases: [PersistentIdentifier: String] = [:]
		var buddies: [PersistentIdentifier: String] = [:]
		var equipment: [PersistentIdentifier: String] = [:]
		/// Gas array index → XML id, for `<switchmix>` in waypoints.
		var gasIndex: [Int: String] = [:]
	}

	enum ExportError: LocalizedError {
		case noData

		var errorDescription: String? {
			switch self {
				case .noData: "No data to export."
			}
		}
	}

	/// Exports the selected parts of the logbook to a UDDF file at the given URL.
	static func export(
		from context: ModelContext,
		selecting selection: UDDFExportSelection = .all,
		to destinationURL: URL
	) throws {
		let xml = try exportString(from: context, selecting: selection)
		try xml.write(to: destinationURL, atomically: true, encoding: .utf8)
	}

	/// Builds the selected parts of the logbook as a UDDF 3.2.2 XML string.
	/// Split out from `export(from:selecting:to:)` so tests and round-trip
	/// checks can assert on the XML content directly, with no filesystem I/O.
	///
	/// Unselected categories are simply omitted, along with any links pointing
	/// at them: a dive whose site is excluded still exports, just without its
	/// `<link>` to that site.
	static func exportString(
		from context: ModelContext,
		selecting selection: UDDFExportSelection = .all
	) throws -> String {
		let dives = selection.contains(.dives)
		? try context.fetch(FetchDescriptor<Dive>(sortBy: [SortDescriptor(\.date)]))
		: []
		let sites = selection.contains(.diveSites)
		? try context.fetch(FetchDescriptor<DiveSite>(sortBy: [SortDescriptor(\.name)]))
		: []
		let gases = selection.contains(.gasMixes) ? try context.fetch(FetchDescriptor<GasMix>()) : []
		let buddies = selection.contains(.buddies) ? try context.fetch(FetchDescriptor<Buddy>()) : []
		let equipment = selection.contains(.equipment) ? try context.fetch(FetchDescriptor<Equipment>()) : []
		let certifications = selection.contains(.certifications)
		? try context.fetch(FetchDescriptor<Certification>())
		: []
		let trips = selection.contains(.trips) ? try context.fetch(FetchDescriptor<Trip>()) : []
		let owner = selection.contains(.diverProfile) ? try? LogbookOwner.fetchOrCreate(in: context) : nil

		let hasOwnerDetails = owner?.hasPersonalDetails ?? false
		let hasContent = !dives.isEmpty || !sites.isEmpty || !gases.isEmpty || !buddies.isEmpty
		|| !equipment.isEmpty || !certifications.isEmpty || !trips.isEmpty || hasOwnerDetails
		guard hasContent else {
			throw ExportError.noData
		}

		// Build persistent ID → externalId maps for relationship lookups. Only
		// exported records land in these maps, so a `<link>` is written only
		// when its target is actually in the file.
		var ids = XMLIdMaps()
		for site in sites { ids.sites[site.persistentModelID] = UDDFIdentifier.xmlID(for: site.externalId) }
		for gas in gases { ids.gases[gas.persistentModelID] = UDDFIdentifier.xmlID(for: gas.externalId) }
		for buddy in buddies { ids.buddies[buddy.persistentModelID] = UDDFIdentifier.xmlID(for: buddy.externalId) }
		for item in equipment { ids.equipment[item.persistentModelID] = UDDFIdentifier.xmlID(for: item.externalId) }
		for dive in dives { ids.dives[dive.persistentModelID] = UDDFIdentifier.xmlID(for: dive.externalId) }

		// Gas array-index → XML id map for switchmix resolution in waypoints
		for (i, gas) in gases.enumerated() { ids.gasIndex[i] = UDDFIdentifier.xmlID(for: gas.externalId) }

		// SwiftData relationship faulting workaround: when DepthSample objects are
		// accessed through `dive.diveProfile`, their optional properties (ppo2Bar,
		// cnsPercent, decoType, tankPressureBar, etc.) return nil even when values
		// exist in the store. Fetching all samples directly via FetchDescriptor and
		// grouping by dive avoids the lazy-loading path and preserves the data.
		var samplesByDive: [PersistentIdentifier: [DepthSample]] = [:]
		if !dives.isEmpty {
			let allSamples = try context.fetch(FetchDescriptor<DepthSample>())
			for sample in allSamples {
				if let dive = sample.dive {
					samplesByDive[dive.persistentModelID, default: []].append(sample)
				}
			}
		}

		var xml = XMLBuilder()
		xml.rawLine("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
		xml.open("uddf", attributes: [
			("xmlns", "http://www.streit.cc/uddf/3.2/"),
			("version", "3.2.2")
		])

		writeGenerator(&xml)
		// The <diver> section holds the owner, their equipment and education,
		// and every buddy, so it is only written when at least one of those
		// categories is part of the export.
		if owner != nil || !buddies.isEmpty || !equipment.isEmpty || !certifications.isEmpty {
			writeDiver(&xml, owner: owner, buddies: buddies, buddyIdMap: ids.buddies,
					   equipment: equipment, certifications: certifications)
		}
		writeDiveSites(&xml, sites: sites, siteIdMap: ids.sites)
		writeGasDefinitions(&xml, gases: gases, gasIdMap: ids.gases)
		writeProfileData(&xml, dives: dives, ids: ids, samplesByDive: samplesByDive)
		writeTrips(&xml, trips: trips, diveIdMap: ids.dives)

		xml.close("uddf")

		return xml.result
	}

	// MARK: - Generator

	private static func writeGenerator(_ xml: inout XMLBuilder) {
		xml.open("generator")
		xml.element("name", value: "WaterLogged")
		xml.element("type", value: "logbook")
		writeManufacturer(&xml, name: "WaterLogged", id: "wl-generator-manufacturer")
		let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
		xml.element("version", value: version)
		xml.element("datetime", value: XMLBuilder.formatISO8601Date(.now))
		xml.close("generator")
	}

	/// Writes a `<manufacturer>` element. `manufacturerType` extends `namedType`,
	/// so it carries a required `xs:ID` and a `<name>` child rather than text.
	private static func writeManufacturer(_ xml: inout XMLBuilder, name: String, id: String) {
		xml.open("manufacturer", attributes: [("id", id)])
		xml.element("name", value: name)
		xml.close("manufacturer")
	}

	// MARK: - Diver (Owner + Buddies)

	private static func writeDiver(
		_ xml: inout XMLBuilder,
		owner: LogbookOwner?,
		buddies: [Buddy],
		buddyIdMap: [PersistentIdentifier: String],
		equipment: [Equipment],
		certifications: [Certification]
	) {
		xml.open("diver")

		// <diver> requires an <owner>, even when the diver profile itself was not
		// selected for export, because the equipment and education below live
		// inside it.
		let ownerId = owner.map { UDDFIdentifier.xmlID(for: $0.externalId) } ?? "wl-owner"
		xml.open("owner", attributes: [("id", ownerId)])
		writePersonal(&xml, firstName: owner?.givenName ?? "", lastName: owner?.familyName ?? "")
		if let owner {
			writeAddress(&xml, street: owner.street, city: owner.city,
						 province: owner.province.isEmpty ? owner.state : owner.province,
						 postalCode: owner.postalCode, country: owner.country)
			writeContact(&xml, phone: owner.telephone, email: owner.email, homepage: owner.webPage)
		}
		if !equipment.isEmpty { writeEquipment(&xml, equipment: equipment) }
		if !certifications.isEmpty { writeEducation(&xml, certifications: certifications) }
		xml.close("owner")

		for buddy in buddies {
			guard let xmlId = buddyIdMap[buddy.persistentModelID] else { continue }
			xml.open("buddy", attributes: [("id", xmlId)])
			writePersonal(&xml, firstName: buddy.givenName, lastName: buddy.familyName)
			writeAddress(&xml, street: buddy.street, city: buddy.city,
						 province: buddy.province.isEmpty ? buddy.state : buddy.province,
						 postalCode: buddy.postalCode, country: buddy.country)
			writeContact(&xml, phone: buddy.telephone, email: buddy.email, homepage: buddy.webPage)
			xml.close("buddy")
		}

		xml.close("diver")
	}

	/// Writes `<personal>`, which `individualType` requires. `firstname` and
	/// `lastname` are themselves required, so they are written even when empty.
	private static func writePersonal(_ xml: inout XMLBuilder, firstName: String, lastName: String) {
		xml.open("personal")
		xml.element("firstname", value: firstName)
		xml.element("lastname", value: lastName)
		xml.close("personal")
	}

	/// Writes `<address>`. `addressType` is an `xs:all` whose only required child
	/// is `country`, and it has no `state` element — a US state is carried in
	/// `province` instead.
	private static func writeAddress(
		_ xml: inout XMLBuilder,
		street: String, city: String,
		province: String, postalCode: String, country: String
	) {
		let hasAddress = !street.isEmpty || !city.isEmpty
		|| !province.isEmpty || !postalCode.isEmpty || !country.isEmpty
		guard hasAddress else { return }
		xml.open("address")
		if !street.isEmpty { xml.element("street", value: street) }
		if !city.isEmpty { xml.element("city", value: city) }
		if !postalCode.isEmpty { xml.element("postcode", value: postalCode) }
		xml.element("country", value: country)
		if !province.isEmpty { xml.element("province", value: province) }
		xml.close("address")
	}

	/// Writes `<contact>`, whose telephone element is named `phone`.
	private static func writeContact(_ xml: inout XMLBuilder, phone: String, email: String, homepage: String) {
		guard !phone.isEmpty || !email.isEmpty || !homepage.isEmpty else { return }
		xml.open("contact")
		if !phone.isEmpty { xml.element("phone", value: phone) }
		if !email.isEmpty { xml.element("email", value: email) }
		if !homepage.isEmpty { xml.element("homepage", value: homepage) }
		xml.close("contact")
	}

	// MARK: - Equipment

	/// The order in which `equipmentType` declares its per-kind elements. It is an
	/// `xs:sequence`, so all `<mask>` elements must be adjacent and must appear
	/// before the first `<regulator>`, and so on.
	private static let equipmentTagOrder = [
		"boots", "buoyancycontroldevice", "camera", "compass", "compressor",
		"divecomputer", "equipmentconfiguration", "fins", "gloves", "knife",
		"lead", "light", "mask", "rebreather", "regulator", "scooter", "suit",
		"tank", "variouspieces", "videocamera", "watch"
	]

	/// Kinds whose type extends `ID_TYPE` rather than `equipmentPieceType`, so
	/// they carry no name/manufacturer/model of their own — those belong to a
	/// nested sub-piece (`body`, `lens`, `housing`, `flash`/`light`).
	private static let compositeEquipmentTags: Set<String> = ["camera", "videocamera"]

	private static func writeEquipment(_ xml: inout XMLBuilder, equipment: [Equipment]) {
		// Group by UDDF tag and emit the groups in the schema's declared order.
		let grouped = Dictionary(grouping: equipment) { $0.resolvedType.uddfTag }

		xml.open("equipment")
		for tag in equipmentTagOrder {
			for item in grouped[tag] ?? [] {
				let itemId = UDDFIdentifier.xmlID(for: item.externalId)
				if compositeEquipmentTags.contains(tag) {
					// We track a camera as one item, so its details go in <body>,
					// the sub-piece common to both cameraType and videocameraType.
					xml.open(tag, attributes: [("id", itemId)])
					writeEquipmentPiece(&xml, item: item, tag: "body",
										id: UDDFIdentifier.xmlID(for: item.externalId, suffix: "body"))
					xml.close(tag)
				} else {
					writeEquipmentPiece(&xml, item: item, tag: tag, id: itemId)
				}
			}
		}
		xml.close("equipment")
	}

	/// Writes one `equipmentPieceType` element: an `xs:sequence` of `name`
	/// (required by `namedType`), then link, manufacturer, model, serialnumber,
	/// purchase, serviceinterval, nextservicedate, notes.
	private static func writeEquipmentPiece(
		_ xml: inout XMLBuilder,
		item: Equipment,
		tag: String,
		id: String
	) {
		xml.open(tag, attributes: [("id", id)])
		xml.element("name", value: item.name)
		if !item.manufacturer.isEmpty {
			writeManufacturer(&xml, name: item.manufacturer,
							  id: UDDFIdentifier.xmlID(for: item.externalId, suffix: "manufacturer"))
		}
		if !item.model.isEmpty { xml.element("model", value: item.model) }
		if !item.serialNumber.isEmpty { xml.element("serialnumber", value: item.serialNumber) }
		if item.purchaseDate != nil || item.purchasePrice != nil {
			xml.open("purchase")
			if let date = item.purchaseDate {
				xml.element("datetime", value: XMLBuilder.formatISO8601Date(date))
			}
			if let price = item.purchasePrice {
				xml.element("price", value: XMLBuilder.formatDecimal(price))
			}
			xml.close("purchase")
		}
		xml.close(tag)
	}

	// MARK: - Education (Certifications)

	/// Writes `<education>`.
	///
	/// `certificationType` takes no `id` attribute and starts with a *choice* of
	/// `level` or `specialty` — not both — so the certification's full name goes
	/// into `level`, which keeps it lossless. The agency element is spelled
	/// `organization`, and `instructor` precedes `issuedate`.
	private static func writeEducation(_ xml: inout XMLBuilder, certifications: [Certification]) {
		xml.open("education")
		for cert in certifications {
			xml.open("certification")

			xml.element("level", value: cert.name)

			if !cert.issuingAgency.isEmpty { xml.element("organization", value: cert.issuingAgency) }
			if !cert.instructorName.isEmpty {
				// instructorType extends individualType: an id and <personal>.
				xml.open("instructor", attributes: [
					("id", UDDFIdentifier.xmlID(for: cert.externalId, suffix: "instructor"))
				])
				let nameParts = cert.instructorName.split(separator: " ", maxSplits: 1)
				writePersonal(&xml,
							  firstName: nameParts.first.map(String.init) ?? "",
							  lastName: nameParts.count >= 2 ? String(nameParts[1]) : "")
				xml.close("instructor")
			}
			if let date = cert.dateAchieved {
				xml.open("issuedate")
				xml.element("datetime", value: XMLBuilder.formatISO8601Date(date))
				xml.close("issuedate")
			}

			xml.close("certification")
		}
		xml.close("education")
	}

	// MARK: - Dive Sites

	private static func writeDiveSites(
		_ xml: inout XMLBuilder,
		sites: [DiveSite],
		siteIdMap: [PersistentIdentifier: String]
	) {
		guard !sites.isEmpty else { return }
		xml.open("divesite")
		for site in sites {
			guard let xmlId = siteIdMap[site.persistentModelID] else { continue }
			xml.open("site", attributes: [("id", xmlId)])
			// <name> is required by namedType.
			xml.element("name", value: site.name)

			let hasGeo = !site.country.isEmpty || !site.region.isEmpty
			|| site.latitude != nil || site.longitude != nil
			if hasGeo {
				// geographyType requires <location>, and the country and region
				// belong to a nested <address> rather than to <geography> itself.
				xml.open("geography")
				xml.element("location", value: site.name)
				writeAddress(&xml, street: "", city: "", province: site.region,
							 postalCode: "", country: site.country)
				if let lat = site.latitude { xml.element("latitude", value: XMLBuilder.formatDecimal(lat)) }
				if let lng = site.longitude { xml.element("longitude", value: XMLBuilder.formatDecimal(lng)) }
				xml.close("geography")
			}

			xml.close("site")
		}
		xml.close("divesite")
	}

	// MARK: - Gas Definitions

	private static func writeGasDefinitions(
		_ xml: inout XMLBuilder,
		gases: [GasMix],
		gasIdMap: [PersistentIdentifier: String]
	) {
		guard !gases.isEmpty else { return }
		xml.open("gasdefinitions")
		for gas in gases {
			guard let xmlId = gasIdMap[gas.persistentModelID] else { continue }
			xml.open("mix", attributes: [("id", xmlId)])
			// <name> is required by namedType; fall back to the derived label.
			xml.element("name", value: gas.name.isEmpty ? gas.displayName : gas.name)
			xml.element("o2", value: XMLBuilder.formatDecimal(gas.oxygenPercent / 100.0))
			xml.element("n2", value: XMLBuilder.formatDecimal(gas.nitrogenPercent / 100.0))
			xml.element("he", value: XMLBuilder.formatDecimal(gas.heliumPercent / 100.0))
			xml.element("ar", value: XMLBuilder.formatDecimal(gas.argonPercent / 100.0))
			xml.element("h2", value: XMLBuilder.formatDecimal(gas.hydrogenPercent / 100.0))
			xml.close("mix")
		}
		xml.close("gasdefinitions")
	}

	// MARK: - Profile Data (Dives)

	private static func writeProfileData(
		_ xml: inout XMLBuilder,
		dives: [Dive],
		ids: XMLIdMaps,
		samplesByDive: [PersistentIdentifier: [DepthSample]]
	) {
		guard !dives.isEmpty else { return }
		xml.open("profiledata")
		xml.open("repetitiongroup", attributes: [("id", "rg")])

		for dive in dives {
			guard let diveXmlId = ids.dives[dive.persistentModelID] else { continue }
			xml.open("dive", attributes: [("id", diveXmlId)])
			writeInfoBefore(&xml, dive: dive, ids: ids)
			writeTankData(&xml, dive: dive, gasIdMap: ids.gases)
			writeWaypoints(&xml, samples: samplesByDive[dive.persistentModelID] ?? [], gasIndexMap: ids.gasIndex)
			writeInfoAfter(&xml, dive: dive)
			xml.close("dive")
		}

		xml.close("repetitiongroup")
		xml.close("profiledata")
	}

	/// Writes `<informationbeforedive>`.
	///
	/// `informationbeforediveType` is an `xs:sequence`, so the child order below
	/// is fixed by the schema and must not be rearranged: `link`, `divenumber`,
	/// `divenumberofday`, `internaldivenumber`, `datetime`, `airtemperature`,
	/// `surfaceintervalbeforedive`, `altitude`, `equipmentused`, …
	private static func writeInfoBefore(
		_ xml: inout XMLBuilder,
		dive: Dive,
		ids: XMLIdMaps
	) {
		xml.open("informationbeforedive")

		// Cross-references to the dive site and buddies come first in the sequence.
		if let site = dive.site, let ref = ids.sites[site.persistentModelID] {
			xml.selfClosing("link", attributes: [("ref", ref)])
		}
		if let buddies = dive.buddies {
			for buddy in buddies {
				if let ref = ids.buddies[buddy.persistentModelID] {
					xml.selfClosing("link", attributes: [("ref", ref)])
				}
			}
		}

		if dive.diveNumber > 0 { xml.element("divenumber", value: "\(dive.diveNumber)") }
		xml.element("datetime", value: XMLBuilder.formatISO8601Date(dive.date))
		if let airTemp = dive.airTempCelsius {
			xml.element("airtemperature", value: XMLBuilder.formatDecimal(celsiusToKelvin(airTemp)))
		}
		// surfaceintervalType is element-only: <passedtime> or <infinity/>.
		if let si = dive.surfaceIntervalSeconds {
			xml.open("surfaceintervalbeforedive")
			xml.element("passedtime", value: "\(si)")
			xml.close("surfaceintervalbeforedive")
		}

		writeEquipmentUsed(&xml, dive: dive, equipmentIdMap: ids.equipment)

		xml.close("informationbeforedive")
	}

	/// Writes the `<equipmentused>` block: the weight carried on the dive and
	/// links to the gear worn on it.
	///
	/// Per the schema this is an optional `<leadquantity>` (kilograms) followed
	/// by any number of `<link ref="…"/>` elements, and `ref` is an `IDREF`, so
	/// only equipment that was itself exported may be referenced.
	private static func writeEquipmentUsed(
		_ xml: inout XMLBuilder,
		dive: Dive,
		equipmentIdMap: [PersistentIdentifier: String]
	) {
		let refs = (dive.equipment ?? [])
			.compactMap { equipmentIdMap[$0.persistentModelID] }
			.sorted()
		guard dive.weightKg != nil || !refs.isEmpty else { return }

		xml.open("equipmentused")
		if let weight = dive.weightKg {
			xml.element("leadquantity", value: XMLBuilder.formatDecimal(weight))
		}
		for ref in refs {
			xml.selfClosing("link", attributes: [("ref", ref)])
		}
		xml.close("equipmentused")
	}

	private static func writeTankData(
		_ xml: inout XMLBuilder,
		dive: Dive,
		gasIdMap: [PersistentIdentifier: String]
	) {
		let tanks = dive.tanks ?? []
		for tank in tanks {
			// tankdataType requires <tankpressurebegin>, so a tank with no
			// starting pressure cannot be represented; its gas mix, if any, is
			// still reachable through the waypoints' <switchmix>. Surfaced to
			// the user as UDDFOmittedDataGroup.gasMixes.
			guard let start = tank.startPressureBar else { continue }

			xml.open("tankdata")
			if let gas = tank.gasMix, let ref = gasIdMap[gas.persistentModelID] {
				xml.selfClosing("link", attributes: [("ref", ref)])
			}
			xml.element("tankpressurebegin", value: XMLBuilder.formatDecimal(barToPascals(start)))
			if let end = tank.endPressureBar { xml.element("tankpressureend", value: XMLBuilder.formatDecimal(barToPascals(end))) }
			xml.close("tankdata")
		}
	}

	/// Accepts pre-fetched samples rather than reading `dive.depthProfile`
	/// to work around SwiftData relationship faulting (see comment in `export`).
	private static func writeWaypoints(
		_ xml: inout XMLBuilder,
		samples: [DepthSample],
		gasIndexMap: [Int: String]
	) {
		guard !samples.isEmpty else { return }

		xml.open("samples")
		for sample in samples.sorted(by: { $0.elapsedSeconds < $1.elapsedSeconds }) {
			// waypointType is an xs:sequence; this order is fixed by the schema:
			// alarm, cns, decostop, depth, divetime, heading, pulserate,
			// remainingbottomtime, setpo2, switchmix, tankpressure, temperature,
			// measuredpo2, nodecotime.
			xml.open("waypoint")

			for alarm in (sample.events ?? []).compactMap(uddfAlarm(for:)) {
				xml.element("alarm", value: alarm)
			}
			if let cns = sample.cnsPercent { xml.element("cns", value: XMLBuilder.formatDecimal(cns)) }
			writeDecoStop(&xml, sample: sample)
			xml.element("depth", value: XMLBuilder.formatDecimal(sample.depthMeters))
			xml.element("divetime", value: "\(sample.elapsedSeconds)")
			if let heading = sample.bearingDegrees { xml.element("heading", value: "\(heading)") }
			if let hr = sample.heartbeatBPM { xml.element("pulserate", value: "\(hr)") }
			if let rbt = sample.rbtSeconds { xml.element("remainingbottomtime", value: "\(rbt)") }
			if let sp = sample.setpointBar {
				// setpo2 requires a setby attribute; our setpoints come from the computer.
				xml.element("setpo2", value: XMLBuilder.formatDecimal(barToPascals(sp)),
							attributes: [("setby", "computer")])
			}
			if let gi = sample.activeGasMixIndex, let ref = gasIndexMap[gi] {
				xml.selfClosing("switchmix", attributes: [("ref", ref)])
			}
			if let p = sample.tankPressureBar { xml.element("tankpressure", value: XMLBuilder.formatDecimal(barToPascals(p))) }
			if let p2 = sample.tank2PressureBar { xml.element("tankpressure", value: XMLBuilder.formatDecimal(barToPascals(p2))) }
			if let t = sample.waterTempCelsius { xml.element("temperature", value: XMLBuilder.formatDecimal(celsiusToKelvin(t))) }
			if let v = sample.ppo2Bar { xml.element("measuredpo2", value: XMLBuilder.formatDecimal(barToPascals(v))) }
			if let v2 = sample.ppo2Sensor2Bar { xml.element("measuredpo2", value: XMLBuilder.formatDecimal(barToPascals(v2))) }
			if let v3 = sample.ppo2Sensor3Bar { xml.element("measuredpo2", value: XMLBuilder.formatDecimal(barToPascals(v3))) }
			if sample.decoStatus == .noDecoLimit, let time = sample.decoTimeSeconds {
				xml.element("nodecotime", value: "\(time)")
			}

			xml.close("waypoint")
		}
		xml.close("samples")
	}

	/// Writes `<decostop>`, whose `kind`, `decodepth` and `duration` attributes
	/// are all required, and whose `kind` may only be `safety` or `mandatory`.
	private static func writeDecoStop(_ xml: inout XMLBuilder, sample: DepthSample) {
		guard let kind = sample.decoStatus?.uddfDecoStopKind,
			  let depth = sample.decoDepthMeters,
			  let duration = sample.decoTimeSeconds else { return }

		xml.selfClosing("decostop", attributes: [
			("kind", kind),
			("decodepth", XMLBuilder.formatDecimal(depth)),
			("duration", "\(duration)")
		])
	}

	/// The UDDF `alarmType` enumeration. Dive-computer events that have no
	/// equivalent are dropped rather than written as invalid values.
	private static let uddfAlarms: Set<String> = [
		"ascent", "breath", "deco", "error", "link",
		"microbubbles", "rbt", "skincooling", "surface"
	]

	private static func uddfAlarm(for event: String) -> String? {
		let normalized = event.lowercased()
		return uddfAlarms.contains(normalized) ? normalized : nil
	}

	private static func writeInfoAfter(_ xml: inout XMLBuilder, dive: Dive) {
		xml.open("informationafterdive")
		// greatestdepth and diveduration are required, so they are written even
		// when zero.
		xml.element("greatestdepth", value: XMLBuilder.formatDecimal(dive.maxDepthMeters))
		xml.element("diveduration", value: "\(dive.durationSeconds)")
		if let wt = dive.waterTempCelsius { xml.element("lowesttemperature", value: XMLBuilder.formatDecimal(celsiusToKelvin(wt))) }
		if let vis = dive.visibilityMeters { xml.element("visibility", value: XMLBuilder.formatDecimal(vis)) }
		if dive.rating > 0 {
			xml.open("rating")
			xml.element("ratingvalue", value: "\(dive.rating)")
			xml.close("rating")
		}
		if !dive.notes.isEmpty {
			xml.open("notes")
			for paragraph in splitNotesPreservingBlankLines(dive.notes) {
				xml.element("para", value: paragraph)
			}
			xml.close("notes")
		}
		xml.close("informationafterdive")
	}

	// MARK: - Trips

	private static func writeTrips(
		_ xml: inout XMLBuilder,
		trips: [Trip],
		diveIdMap: [PersistentIdentifier: String]
	) {
		guard !trips.isEmpty else { return }
		xml.open("divetrip")

		for trip in trips {
			xml.open("trip", attributes: [("id", UDDFIdentifier.xmlID(for: trip.externalId))])
			// <name> is required by namedType on <trip> and by simpleNamedType on
			// <trippart>.
			xml.element("name", value: trip.name)

			xml.open("trippart")
			xml.element("name", value: trip.name)

			// startdate and enddate are xs:dateTime, not dates.
			xml.selfClosing("dateoftrip", attributes: [
				("startdate", XMLBuilder.formatISO8601Date(trip.startDate)),
				("enddate", XMLBuilder.formatISO8601Date(trip.endDate))
			])

			let hasGeo = !trip.location.isEmpty || trip.latitude != nil || trip.longitude != nil
			if hasGeo {
				// geographyType requires <location>.
				xml.open("geography")
				xml.element("location", value: trip.location.isEmpty ? trip.name : trip.location)
				if let lat = trip.latitude { xml.element("latitude", value: XMLBuilder.formatDecimal(lat)) }
				if let lng = trip.longitude { xml.element("longitude", value: XMLBuilder.formatDecimal(lng)) }
				xml.close("geography")
			}

			if let dives = trip.dives, !dives.isEmpty {
				xml.open("relateddives")
				for dive in dives {
					if let ref = diveIdMap[dive.persistentModelID] {
						xml.selfClosing("link", attributes: [("ref", ref)])
					}
				}
				xml.close("relateddives")
			}

			if !trip.notes.isEmpty {
				xml.open("notes")
				for paragraph in splitNotesPreservingBlankLines(trip.notes) {
					xml.element("para", value: paragraph)
				}
				xml.close("notes")
			}

			xml.close("trippart")
			xml.close("trip")
		}

		xml.close("divetrip")
	}

	// MARK: - Unit Conversions

	private static func celsiusToKelvin(_ celsius: Double) -> Double {
		celsius + 273.15
	}

	private static func barToPascals(_ bar: Double) -> Double {
		bar * 100_000
	}

	// MARK: - Notes

	/// Splits a free-text notes field into paragraphs while preserving every
	/// blank line. Normalizes CRLF/CR to LF first because Swift treats `\r\n`
	/// as a single grapheme cluster, which makes `split(separator: "\n")` fail
	/// to break the string when notes contain Windows-style line endings (e.g.
	/// pasted from email or a webpage).
	private static func splitNotesPreservingBlankLines(_ text: String) -> [String] {
		let normalized = text
			.replacing("\r\n", with: "\n")
			.replacing("\r", with: "\n")
		return normalized
			.split(separator: "\n", omittingEmptySubsequences: false)
			.map(String.init)
	}
}
