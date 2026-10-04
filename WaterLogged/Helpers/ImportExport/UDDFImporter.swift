//
//  UDDFImporter.swift
//  WaterLogged
//
//  Created by John Meyer on 2/24/26.
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

/// Parses UDDF (Universal Dive Data Format) XML files and imports dives
/// into the SwiftData model context.
///
/// Supports UDDF v2.x and v3.x files. UDDF uses SI units internally:
/// - Depth: meters
/// - Temperature: Kelvin
/// - Pressure: Pascals
/// - Time: seconds
/// - Gas fractions: 0.0–1.0
struct UDDFImporter {

	enum ImportError: LocalizedError {
		case parsingFailed(String)
		case noImportableData

		var errorDescription: String? {
			switch self {
				case .parsingFailed(let detail): "Failed to parse UDDF file: \(detail)"
				case .noImportableData: "No importable data was found in the UDDF file."
			}
		}
	}

	/// A tally of the entities imported from a UDDF file. UDDF files may contain
	/// any combination of dives, dive sites, buddies, equipment, certifications,
	/// and trips (or none of them), so callers use this to report exactly what
	/// was imported rather than assuming the file contained dives.
	struct ImportSummary {
		var dives = 0
		var sites = 0
		var buddies = 0
		var equipment = 0
		var certifications = 0
		var trips = 0
		var ownerImported = false

		/// The number of individually countable items imported (the diver
		/// profile is a single update rather than a countable item).
		var total: Int {
			dives + sites + buddies + equipment + certifications + trips
		}

		var isEmpty: Bool {
			total == 0 && !ownerImported
		}

		/// A human-readable summary of what was imported, for display in an alert.
		var message: String {
			var parts: [String] = []
			func add(_ count: Int, singular: String, plural: String) {
				guard count > 0 else { return }
				parts.append("\(count) \(count == 1 ? singular : plural)")
			}
			add(dives, singular: "dive", plural: "dives")
			add(sites, singular: "dive site", plural: "dive sites")
			add(buddies, singular: "buddy", plural: "buddies")
			add(equipment, singular: "equipment item", plural: "equipment items")
			add(certifications, singular: "certification", plural: "certifications")
			add(trips, singular: "trip", plural: "trips")

			guard !parts.isEmpty else {
				return ownerImported
				? "Imported the diver profile."
				: "No importable data was found."
			}

			let list = parts.formatted(.list(type: .and))
			return ownerImported
			? "Imported \(list), and the diver profile."
			: "Imported \(list)."
		}
	}

	/// Import dives from a UDDF file URL into the given model context.
	/// Returns a summary of the entities imported.
	///
	/// UDDF files need not contain dives — a file may hold only dive sites,
	/// equipment, certifications, and so on. Every top-level entity is imported
	/// regardless of whether any dives are present.
	///
	/// - Parameter shouldSave: When `false`, the caller is responsible for
	///   calling `context.save()`. Used by `RestorePackager` to commit the
	///   UDDF import and extras application as a single atomic save.
	@discardableResult
	static func importFile(at url: URL, into context: ModelContext, shouldSave: Bool = true) throws -> ImportSummary {
		let accessing = url.startAccessingSecurityScopedResource()
		defer { if accessing { url.stopAccessingSecurityScopedResource() } }

		let data = try Data(contentsOf: url)
		return try importData(data, into: context, shouldSave: shouldSave)
	}

	/// Parse UDDF XML text into the intermediate representation without touching
	/// SwiftData. Convenience wrapper over `parse(data:)` for string fixtures and
	/// parser-level unit tests.
	static func parse(xml: String) throws -> UDDFParseResult {
		try parse(data: Data(xml.utf8))
	}

	/// Parse raw UDDF bytes into the intermediate representation. Handles the
	/// bare-ampersand escaping that other exporters commonly emit, then runs the
	/// XML parser. No SwiftData involvement, so it is cheap and side-effect free.
	static func parse(data rawData: Data) throws -> UDDFParseResult {
		let data: Data
		if var xml = String(data: rawData, encoding: .utf8) {
			// Bare ampersands are common in UDDF files from other exporters
			xml = xml.replacing(/&(?!amp;|lt;|gt;|apos;|quot;|#)/, with: "&amp;")
			data = Data(xml.utf8)
		} else {
			data = rawData
		}
		let parser = UDDFParser(data: data)
		return try parser.parse()
	}

	/// Import every entity from raw UDDF bytes into `context`. Split out from
	/// `importFile(at:)` so tests can drive imports from in-memory data with no
	/// filesystem or security-scoped resource access.
	@discardableResult
	static func importData(_ data: Data, into context: ModelContext, shouldSave: Bool = true) throws -> ImportSummary {
		let result = try parse(data: data)

		var summary = ImportSummary()

		// Import owner
		if let parsedOwner = result.owner {
			mapOwner(parsedOwner, context: context)
			summary.ownerImported = true
		}

		// Import certifications
		let logbookOwner = try? LogbookOwner.fetchOrCreate(in: context)
		for parsedCert in result.certifications {
			let cert = mapCertification(parsedCert, owner: logbookOwner, context: context)
			context.insert(cert)
			summary.certifications += 1
		}

		// Import standalone dive sites and buddies. These are normally created
		// on demand while importing the dives that reference them, but a UDDF
		// file may list sites or buddies that no dive references — or contain no
		// dives at all — so import them up front. Sites and buddies referenced
		// by dives are then matched to these records during the dives loop.
		for (uddfId, parsedSite) in result.sites where siteHasContent(parsedSite) {
			_ = findOrCreateSite(parsedSite, uddfId: uddfId, context: context)
			summary.sites += 1
		}
		for (uddfId, parsedBuddy) in result.buddies
				where !parsedBuddy.firstName.isEmpty || !parsedBuddy.lastName.isEmpty {
			_ = findOrCreateBuddy(parsedBuddy, uddfId: uddfId, context: context)
			summary.buddies += 1
		}

		// Import equipment and service records. Keyed by the id used in the file
		// (not the model's externalId, which an already-matched item keeps) so
		// that <equipmentused> links on the dives below can be resolved.
		var equipmentByRef: [String: Equipment] = [:]
		for parsedEquipment in result.equipment {
			let equipment = findOrCreateEquipment(parsedEquipment, context: context)
			context.insert(equipment)
			summary.equipment += 1
			if let ref = parsedEquipment.id { equipmentByRef[ref] = equipment }

			if let nextService = parsedEquipment.nextServiceDate {
				var notes = "Scheduled service (imported from UDDF)"
				if let interval = parsedEquipment.serviceIntervalDays {
					notes += "\nService interval: \(interval) days"
				}
				let record = ServiceRecord(
					serviceDate: nextService,
					notes: notes
				)
				record.equipment = equipment
				context.insert(record)
			}
		}

		var importedCount = 0
		var divesByRef: [String: Dive] = [:]

		for parsedDive in result.dives {
			let dive = mapDive(parsedDive, sites: result.sites, gases: result.gases, buddies: result.buddies, context: context)

			// Preserve the UDDF id attribute as the model's externalId so that
			// RestorePackager can cross-reference entities between the UDDF and
			// the companion extras.xml file. Without this, restored entities get
			// fresh UUIDs and all extras lookups fail silently.
			if let uddfId = parsedDive.id {
				dive.externalId = uddfId
			}
			context.insert(dive)

			// Attach the gear worn on this dive, from <equipmentused>. Links to
			// equipment the file never defined are ignored.
			let equipmentUsed = parsedDive.equipmentRefs.compactMap { equipmentByRef[$0] }
			if !equipmentUsed.isEmpty {
				dive.equipment = equipmentUsed
			}

			// Create a Tank for each parsed <tankdata> element
			for parsedTank in parsedDive.tanks {
				let tankGasMix: GasMix?
				if let parsedGas = result.gases[parsedTank.mixRef] {
					tankGasMix = GasMix.findOrCreate(
						name: parsedGas.name ?? gasLabel(o2: parsedGas.o2Fraction, he: parsedGas.heFraction),
						oxygenPercent: parsedGas.o2Fraction * 100,
						heliumPercent: parsedGas.heFraction * 100,
						argonPercent: parsedGas.arFraction * 100,
						hydrogenPercent: parsedGas.h2Fraction * 100,
						uddfId: parsedTank.mixRef,
						in: context
					)
				} else {
					tankGasMix = nil
				}
				let tank = Tank(
					gasMix: tankGasMix,
					startPressureBar: parsedTank.startPressureBar,
					endPressureBar: parsedTank.endPressureBar
				)
				tank.dive = dive
				context.insert(tank)
			}

			if let id = parsedDive.id {
				divesByRef[id] = dive
			}

			// Build gas mix ref → index lookup for switchmix resolution
			let mixRefToIndex: [String: Int] = {
				var map: [String: Int] = [:]
				for (index, key) in result.gases.keys.sorted().enumerated() {
					map[key] = index
				}
				return map
			}()

			// Insert depth profile samples
			for sample in parsedDive.waypoints {
				let depthSample = makeDepthSample(from: sample, mixRefToIndex: mixRefToIndex)
				depthSample.dive = dive
				context.insert(depthSample)
			}

			importedCount += 1
		}
		summary.dives = importedCount

		// Import trips and link dives
		for parsedTrip in result.trips {
			let trip = findOrCreateTrip(parsedTrip, context: context)
			context.insert(trip)
			summary.trips += 1
			for ref in parsedTrip.diveRefs {
				if let dive = divesByRef[ref] {
					dive.trip = trip
				}
			}
		}

		if summary.isEmpty {
			throw ImportError.noImportableData
		}

		if shouldSave {
			try context.save()
		}
		return summary
	}

	// MARK: - Mapping

	private static func mapDive(
		_ parsed: ParsedDive,
		sites: [String: ParsedSite],
		gases: [String: ParsedGas],
		buddies buddyData: [String: ParsedBuddy],
		context: ModelContext
	) -> Dive {
		// Resolve or create dive site
		var site: DiveSite?
		if let siteRef = parsed.siteRef, let parsedSite = sites[siteRef] {
			site = findOrCreateSite(parsedSite, uddfId: siteRef, context: context)
		}

		// Resolve buddies
		var buddies: [Buddy] = []
		for ref in parsed.buddyRefs {
			if let parsedBuddy = buddyData[ref],
			   !parsedBuddy.firstName.isEmpty || !parsedBuddy.lastName.isEmpty {
				buddies.append(findOrCreateBuddy(parsedBuddy, uddfId: ref, context: context))
			}
		}

		// Compute max depth from waypoints if not provided in informationafterdive
		let maxDepth = parsed.greatestDepth ?? parsed.waypoints.map(\.depth).max() ?? 0

		// Duration from informationafterdive or last waypoint time
		let duration = parsed.diveDuration ?? Int(parsed.waypoints.map(\.divetime).max() ?? 0)

		// Water temperature from informationafterdive or average of waypoint temps
		let waterTemp: Double? = parsed.lowestTempCelsius ?? {
			let temps = parsed.waypoints.compactMap(\.temperatureCelsius)
			guard !temps.isEmpty else { return nil }
			return temps.reduce(0, +) / Double(temps.count)
		}()

		let dive = Dive(
			diveNumber: parsed.diveNumber ?? 0,
			date: parsed.dateTime ?? .now,
			title: parsed.title,
			maxDepthMeters: maxDepth,
			durationSeconds: duration,
			waterTempCelsius: waterTemp,
			airTempCelsius: parsed.airTempCelsius,
			visibilityMeters: parsed.visibilityMeters,
			weather: "",
			weightKg: parsed.weightKg,
			rating: parsed.rating ?? 0,
			notes: parsed.notes ?? "",
			tags: [],
			importSource: "UDDF",
			site: site
		)

		if let surfaceInterval = parsed.surfaceIntervalSeconds {
			dive.surfaceIntervalSeconds = surfaceInterval
		}

		if !buddies.isEmpty {
			dive.buddies = buddies
		}

		return dive
	}

	/// Build a `DepthSample` from a parsed waypoint, resolving decompression
	/// state (explicit deco stop vs. no-deco time) and the gas-switch index.
	/// Extracted from `importData` to keep the import routine within a reasonable length.
	private static func makeDepthSample(from sample: ParsedWaypoint, mixRefToIndex: [String: Int]) -> DepthSample {
		let effectivePpo2 = sample.ppo2Bar ?? sample.calculatedPpo2Bar

		var decoStatus: DecoType?
		var decoTimeSeconds: Int?
		var decoDepthMeters: Double?

		if let type = sample.decoType {
			decoStatus = type
			decoTimeSeconds = sample.decoTimeSeconds
			decoDepthMeters = sample.decoDepthMeters
		} else if let ndl = sample.nodecoTimeSeconds {
			decoStatus = .noDecoLimit
			decoTimeSeconds = ndl
		}

		return DepthSample(
			elapsedSeconds: Int(sample.divetime),
			depthMeters: sample.depth,
			waterTempCelsius: sample.temperatureCelsius,
			tankPressureBar: sample.tankPressureBar,
			tank2PressureBar: sample.tank2PressureBar,
			ppo2Bar: effectivePpo2,
			ppo2Sensor2Bar: sample.ppo2Sensor2Bar,
			ppo2Sensor3Bar: sample.ppo2Sensor3Bar,
			cnsPercent: sample.cnsPercent,
			setpointBar: sample.setpointBar,
			decoStatus: decoStatus,
			decoTimeSeconds: decoTimeSeconds,
			decoDepthMeters: decoDepthMeters,
			rbtSeconds: sample.rbtSeconds,
			heartbeatBPM: sample.heartbeatBPM,
			bearingDegrees: sample.headingDegrees,
			activeGasMixIndex: sample.switchMixRef.flatMap { mixRefToIndex[$0] },
			events: sample.alarms.isEmpty ? nil : sample.alarms
		)
	}

	private static func mapOwner(_ parsed: ParsedBuddy, context: ModelContext) {
		guard let owner = try? LogbookOwner.fetchOrCreate(in: context) else { return }
		owner.givenName = parsed.firstName
		owner.familyName = parsed.lastName
		owner.street = parsed.street
		owner.city = parsed.city
		owner.state = parsed.state
		owner.province = parsed.province
		owner.postalCode = parsed.postalCode
		owner.country = parsed.country
		owner.telephone = parsed.telephone
		owner.email = parsed.email
		owner.webPage = parsed.webPage
	}

	/// Whether a parsed site carries any meaningful data worth importing,
	/// used to skip empty `<site>` elements when importing sites standalone.
	private static func siteHasContent(_ parsed: ParsedSite) -> Bool {
		!(parsed.name ?? "").isEmpty
		|| !(parsed.country ?? "").isEmpty
		|| !(parsed.province ?? "").isEmpty
		|| parsed.latitude != nil
		|| parsed.longitude != nil
	}

	/// The `uddfId` parameter on each `findOrCreate` method preserves the UDDF
	/// `id` attribute as the model's `externalId`, enabling extras.xml
	/// cross-referencing during restore. Only set on newly created entities so
	/// that existing records are not overwritten during a normal (non-restore) import.
	private static func findOrCreateSite(_ parsed: ParsedSite, uddfId: String? = nil, context: ModelContext) -> DiveSite {
		let name = parsed.name ?? ""
		let country = parsed.country ?? ""

		// Match by name and country to avoid duplicates
		if !name.isEmpty {
			var descriptor = FetchDescriptor<DiveSite>(
				predicate: #Predicate<DiveSite> { $0.name == name && $0.country == country }
			)
			descriptor.fetchLimit = 1
			if let existing = try? context.fetch(descriptor).first {
				return existing
			}
		}

		let site = DiveSite(
			name: name,
			country: country,
			region: parsed.province ?? "",
			latitude: parsed.latitude,
			longitude: parsed.longitude,
			notes: ""
		)
		if let uddfId { site.externalId = uddfId }
		context.insert(site)
		return site
	}

	private static func findOrCreateBuddy(_ parsed: ParsedBuddy, uddfId: String? = nil, context: ModelContext) -> Buddy {
		let givenName = parsed.firstName
		let familyName = parsed.lastName

		var descriptor = FetchDescriptor<Buddy>(
			predicate: #Predicate<Buddy> {
				$0.givenName == givenName && $0.familyName == familyName
			}
		)
		descriptor.fetchLimit = 1
		if let existing = try? context.fetch(descriptor).first {
			return existing
		}

		let buddy = Buddy(
			givenName: givenName,
			familyName: familyName,
			street: parsed.street,
			city: parsed.city,
			state: parsed.state,
			province: parsed.province,
			postalCode: parsed.postalCode,
			country: parsed.country,
			telephone: parsed.telephone,
			email: parsed.email,
			webPage: parsed.webPage
		)
		if let uddfId { buddy.externalId = uddfId }
		context.insert(buddy)
		return buddy
	}

	private static func findOrCreateTrip(_ parsed: ParsedTrip, context: ModelContext) -> Trip {
		let name = parsed.name

		if !name.isEmpty {
			var descriptor = FetchDescriptor<Trip>(
				predicate: #Predicate<Trip> { $0.name == name }
			)
			descriptor.fetchLimit = 1
			if let existing = try? context.fetch(descriptor).first {
				return existing
			}
		}

		let trip = Trip(
			name: name,
			startDate: parsed.startDate ?? .now,
			endDate: parsed.endDate ?? parsed.startDate ?? .now,
			location: parsed.location,
			latitude: parsed.latitude,
			longitude: parsed.longitude,
			notes: parsed.notes ?? ""
		)
		if let id = parsed.id { trip.externalId = id }
		return trip
	}

	private static func findOrCreateEquipment(_ parsed: ParsedEquipment, context: ModelContext) -> Equipment {
		let name = parsed.name
		let serialNumber = parsed.serialNumber

		// Match by serial number if available, otherwise by name + manufacturer
		if !serialNumber.isEmpty {
			var descriptor = FetchDescriptor<Equipment>(
				predicate: #Predicate<Equipment> { $0.serialNumber == serialNumber }
			)
			descriptor.fetchLimit = 1
			if let existing = try? context.fetch(descriptor).first {
				return existing
			}
		} else if !name.isEmpty {
			let manufacturer = parsed.manufacturer
			var descriptor = FetchDescriptor<Equipment>(
				predicate: #Predicate<Equipment> { $0.name == name && $0.manufacturer == manufacturer }
			)
			descriptor.fetchLimit = 1
			if let existing = try? context.fetch(descriptor).first {
				return existing
			}
		}

		let equipment = Equipment(
			name: name,
			type: parsed.type,
			manufacturer: parsed.manufacturer,
			model: parsed.model,
			serialNumber: serialNumber,
			purchaseDate: parsed.purchaseDate,
			purchasePrice: parsed.purchasePrice
		)
		if let id = parsed.id { equipment.externalId = id }
		return equipment
	}

	private static func mapCertification(_ parsed: ParsedCertification, owner: LogbookOwner?, context: ModelContext) -> Certification {
		let name: String
		if !parsed.level.isEmpty && !parsed.specialty.isEmpty {
			name = "\(parsed.level) — \(parsed.specialty)"
		} else if !parsed.level.isEmpty {
			name = parsed.level
		} else {
			name = parsed.specialty
		}

		let instructorName: String = {
			let parts = [parsed.instructorFirstName, parsed.instructorLastName]
				.filter { !$0.isEmpty }
			return parts.joined(separator: " ")
		}()

		let cert = Certification(
			name: name,
			dateAchieved: parsed.issueDate,
			issuingAgency: parsed.organisation,
			instructorName: instructorName
		)
		if let id = parsed.id { cert.externalId = id }
		cert.owner = owner
		return cert
	}

	private static func gasLabel(o2: Double, he: Double) -> String {
		let o2Pct = Int(o2 * 100)
		let hePct = Int(he * 100)
		if hePct > 0 {
			return "Trimix \(o2Pct)/\(hePct)"
		} else if o2Pct == 21 {
			return "Air"
		} else {
			return "EAN\(o2Pct)"
		}
	}
}

// MARK: - Parsed Intermediate Types

struct ParsedGas {
	var name: String?
	var o2Fraction: Double = 0.21
	var n2Fraction: Double?
	var heFraction: Double = 0.0
	var arFraction: Double = 0.0
	var h2Fraction: Double = 0.0

	/// Returns the explicit `n2Fraction` if the UDDF file provided one,
	/// otherwise computes it from the remaining components.
	var resolvedN2Fraction: Double {
		if let explicit = n2Fraction { return explicit }
		return max(0, 1.0 - o2Fraction - heFraction - arFraction - h2Fraction)
	}
}

struct ParsedSite {
	var name: String?
	var country: String?
	var province: String?
	var latitude: Double?
	var longitude: Double?
}

struct ParsedTank {
	var mixRef: String = ""
	var startPressureBar: Double?
	var endPressureBar: Double?
}

struct ParsedWaypoint {
	var divetime: Double = 0
	var depth: Double = 0
	var temperatureCelsius: Double?

	// Tank pressure (Pascals → bar during mapping)
	var tankPressureBar: Double?
	var tank2PressureBar: Double?

	// PPO2 — measured sensors (Pascals → bar during parsing)
	var ppo2Bar: Double?
	var ppo2Sensor2Bar: Double?
	var ppo2Sensor3Bar: Double?

	// PPO2 — calculated (fallback when no measured value)
	var calculatedPpo2Bar: Double?

	// Rebreather setpoint (Pascals → bar during parsing)
	var setpointBar: Double?

	// CNS oxygen toxicity (0–100)
	var cnsPercent: Double?

	// Decompression
	var decoType: DecoType?
	var decoTimeSeconds: Int?
	var decoDepthMeters: Double?

	// No-deco time (seconds)
	var nodecoTimeSeconds: Int?

	// Remaining bottom time (seconds)
	var rbtSeconds: Int?

	// Heart rate (beats per minute)
	var heartbeatBPM: Int?

	// Compass heading (degrees)
	var headingDegrees: Int?

	// Gas switch — mix ref resolved to an index after parsing
	var switchMixRef: String?

	// Alarms
	var alarms: [String] = []
}

struct ParsedDive {
	var id: String?
	var diveNumber: Int?
	var dateTime: Date?
	var title: String = ""
	var siteRef: String?
	var buddyRefs: [String] = []
	/// Equipment ids from `<informationbeforedive><equipmentused><link ref="…"/>`.
	var equipmentRefs: [String] = []
	/// `<equipmentused><leadquantity>`, in kilograms.
	var weightKg: Double?
	var airTempCelsius: Double?
	var tanks: [ParsedTank] = []
	var waypoints: [ParsedWaypoint] = []

	// informationbeforedive
	var surfaceIntervalSeconds: Int?

	// informationafterdive
	var greatestDepth: Double?
	var diveDuration: Int?
	var lowestTempCelsius: Double?
	var visibilityMeters: Double?
	var rating: Int?
	var notes: String?
}

struct ParsedEquipment {
	var id: String?
	var type: EquipmentType = .miscellaneous
	var name: String = ""
	var manufacturer: String = ""
	var model: String = ""
	var serialNumber: String = ""
	var purchaseDate: Date?
	var purchasePrice: Double?
	var nextServiceDate: Date?
	var serviceIntervalDays: Int?
}

struct ParsedCertification {
	var id: String?
	var level: String = ""
	var specialty: String = ""
	var organisation: String = ""
	var instructorFirstName: String = ""
	var instructorLastName: String = ""
	var issueDate: Date?
}

struct ParsedTrip {
	var id: String?
	var name: String = ""
	var startDate: Date?
	var endDate: Date?
	var location: String = ""
	var latitude: Double?
	var longitude: Double?
	var notes: String?
	var diveRefs: [String] = []
}

struct ParsedBuddy {
	var firstName: String = ""
	var lastName: String = ""
	var street: String = ""
	var city: String = ""
	var state: String = ""
	var province: String = ""
	var postalCode: String = ""
	var country: String = ""
	var telephone: String = ""
	var email: String = ""
	var webPage: String = ""
}

struct UDDFParseResult {
	var gases: [String: ParsedGas] = [:]
	var sites: [String: ParsedSite] = [:]
	var buddies: [String: ParsedBuddy] = [:]
	var owner: ParsedBuddy?
	var equipment: [ParsedEquipment] = []
	var certifications: [ParsedCertification] = []
	var dives: [ParsedDive] = []
	var trips: [ParsedTrip] = []
}

// MARK: - XML Parser

private final class UDDFParser: NSObject, XMLParserDelegate {
	private let data: Data
	private var result = UDDFParseResult()

	// Parser state
	private var elementStack: [String] = []
	private var currentText = ""

	// Current objects being built
	private var currentGasId: String?
	private var currentGas = ParsedGas()
	private var currentSiteId: String?
	private var currentSite = ParsedSite()
	private var currentBuddyId: String?
	private var currentBuddy = ParsedBuddy()
	private var currentOwner = ParsedBuddy()
	private var insideOwner = false
	private var currentDive = ParsedDive()
	private var currentTank = ParsedTank()
	private var currentWaypoint = ParsedWaypoint()
	private var currentEquipment: ParsedEquipment?
	private var currentEquipmentTag: String?
	private var currentCertification = ParsedCertification()
	private var insideCertification = false
	private var insideCertInstructor = false
	private var currentTrip = ParsedTrip()
	private var insideDiveTrip = false

	private var currentTankPressureIndex = 0
	private var currentPO2SensorIndex = 0

	private var parsingError: Error?

	init(data: Data) {
		self.data = data
	}

	func parse() throws -> UDDFParseResult {
		let parser = XMLParser(data: data)
		parser.delegate = self
		parser.shouldProcessNamespaces = false

		if !parser.parse() {
			// `parsingError` holds XMLParser's raw NSError (captured in
			// parseErrorOccurred). Wrap it rather than rethrowing it, so callers
			// catching ImportError aren't bypassed by an NSXMLParserErrorDomain
			// NSError leaking out of the importer.
			let underlying = parsingError ?? parser.parserError
			throw UDDFImporter.ImportError.parsingFailed(
				underlying?.localizedDescription ?? "Unknown error"
			)
		}
		return result
	}

	// MARK: - XMLParserDelegate

	func parser(
		_ parser: XMLParser,
		didStartElement elementName: String,
		namespaceURI: String?,
		qualifiedName: String?,
		attributes attributeDict: [String: String]
	) {
		elementStack.append(elementName)
		currentText = ""

		switch elementName {
			case "mix":
				currentGasId = identifier(in: attributeDict)
				currentGas = ParsedGas()

			case "site":
				currentSiteId = identifier(in: attributeDict)
				currentSite = ParsedSite()

			case "buddy":
				currentBuddyId = identifier(in: attributeDict)
				currentBuddy = ParsedBuddy()

			case "owner" where elementStack.contains("diver"):
				currentOwner = ParsedBuddy()
				insideOwner = true

			case "dive":
				currentDive = ParsedDive()
				currentDive.id = identifier(in: attributeDict)

			case "divetrip":
				break

			case "trip":
				currentTrip = ParsedTrip()
				currentTrip.id = identifier(in: attributeDict)
				insideDiveTrip = true

			case "dateoftrip":
				if let start = attributeDict["startdate"] {
					currentTrip.startDate = parseUDDFDate(start)
				}
				if let end = attributeDict["enddate"] {
					currentTrip.endDate = parseUDDFDate(end)
				}

			case "tankdata":
				currentTank = ParsedTank()

			case "waypoint":
				currentWaypoint = ParsedWaypoint()
				currentTankPressureIndex = 0
				currentPO2SensorIndex = 0

			case "certification" where elementStack.contains("education"):
				currentCertification = ParsedCertification()
				currentCertification.id = identifier(in: attributeDict)
				insideCertification = true

			case "instructor" where insideCertification:
				insideCertInstructor = true

			case "decostop" where elementStack.contains("waypoint"):
				let kind = attributeDict["kind"] ?? "mandatory"
				// The schema allows only safety|mandatory, and a <decostop> element
				// always means a stop, so an unrecognized kind falls back to one.
				currentWaypoint.decoType = DecoType(importedValue: kind) ?? .decoStop
				if let depthStr = attributeDict["decodepth"], let depth = Double(depthStr) {
					currentWaypoint.decoDepthMeters = depth
				}
				if let durStr = attributeDict["duration"], let dur = Double(durStr) {
					currentWaypoint.decoTimeSeconds = Int(dur)
				}

			case "tankpressure" where elementStack.contains("waypoint"):
				currentTankPressureIndex += 1

			case "measuredpo2" where elementStack.contains("waypoint"):
				currentPO2SensorIndex += 1

			case _ where elementStack.count >= 2 && elementStack[elementStack.count - 2] == "equipment"
				&& EquipmentType(uddfTag: elementName) != nil:
				currentEquipmentTag = elementName
				currentEquipment = ParsedEquipment(type: EquipmentType(uddfTag: elementName)!)
				currentEquipment?.id = identifier(in: attributeDict)

			case "link":
				// Resolve cross-references
				if let ref = attributeDict["ref"] {
					handleLink(ref: UDDFIdentifier.externalId(from: ref))
				}

			case "switchmix":
				if let ref = attributeDict["ref"].map(UDDFIdentifier.externalId(from:)) {
					if elementStack.contains("waypoint") {
						currentWaypoint.switchMixRef = ref
					} else if currentTank.mixRef.isEmpty {
						currentTank.mixRef = ref
					}
				}

			default:
				break
		}
	}

	func parser(
		_ parser: XMLParser,
		didEndElement elementName: String,
		namespaceURI: String?,
		qualifiedName: String?
	) {
		let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
		let parent = elementStack.count >= 2 ? elementStack[elementStack.count - 2] : ""

		switch elementName {
				// Gas definitions
			case "name" where parent == "mix":
				currentGas.name = text
			case "o2" where parent == "mix":
				currentGas.o2Fraction = Double(text) ?? 0.21
			case "n2" where parent == "mix":
				currentGas.n2Fraction = Double(text)
			case "he" where parent == "mix":
				currentGas.heFraction = Double(text) ?? 0.0
			case "ar" where parent == "mix":
				currentGas.arFraction = Double(text) ?? 0.0
			case "h2" where parent == "mix":
				currentGas.h2Fraction = Double(text) ?? 0.0
			case "mix":
				if let id = currentGasId {
					result.gases[id] = currentGas
				}

				// Dive site
			case "name" where parent == "site":
				currentSite.name = text
			case "name" where parent == "trip":
				currentTrip.name = text
			case "name" where parent == "trippart" && insideDiveTrip && currentTrip.name.isEmpty:
				currentTrip.name = text
			case "country" where isInsideSiteGeography():
				currentSite.country = text
			case "province" where isInsideSiteGeography():
				currentSite.province = text
			case "location" where isInsideSiteGeography():
				// <location> is used as a region/area name in some UDDF exporters
				if currentSite.province == nil {
					currentSite.province = text
				}
			case "latitude" where isInsideSiteGeography():
				currentSite.latitude = Double(text)
			case "longitude" where isInsideSiteGeography():
				currentSite.longitude = Double(text)
			case "latitude" where isInsideDiveTripGeography():
				currentTrip.latitude = Double(text)
			case "longitude" where isInsideDiveTripGeography():
				currentTrip.longitude = Double(text)
			case "location" where isInsideDiveTripGeography():
				currentTrip.location = text
			case "site":
				if let id = currentSiteId {
					result.sites[id] = currentSite
				}

				// Certification instructor (must be checked before owner personal)
			case "firstname" where insideCertInstructor:
				currentCertification.instructorFirstName = text
			case "lastname" where insideCertInstructor:
				currentCertification.instructorLastName = text
			case "instructor" where insideCertification:
				insideCertInstructor = false

				// Certification fields
			case "level" where insideCertification:
				currentCertification.level = text
			case "specialty" where insideCertification:
				currentCertification.specialty = text
			case "organization" where insideCertification:
				currentCertification.organisation = text
			case "organisation" where insideCertification:
				currentCertification.organisation = text
			case "datetime" where parent == "issuedate" && insideCertification:
				currentCertification.issueDate = parseUDDFDate(text)
			case "certification" where insideCertification:
				result.certifications.append(currentCertification)
				insideCertification = false

				// Information before dive
			case "datetime" where parent == "informationbeforedive":
				currentDive.dateTime = parseUDDFDate(text)
			case "divenumber" where parent == "informationbeforedive":
				currentDive.diveNumber = Int(text)
			case "passedtime" where parent == "surfaceintervalbeforedive":
				if let seconds = Double(text), seconds > 0 {
					currentDive.surfaceIntervalSeconds = Int(seconds)
				}
				// Legacy: WaterLogged used to write the seconds as text on the parent.
			case "surfaceintervalbeforedive" where parent == "informationbeforedive":
				if let seconds = Double(text), seconds > 0, currentDive.surfaceIntervalSeconds == nil {
					currentDive.surfaceIntervalSeconds = Int(seconds)
				}
			case "leadquantity" where parent == "equipmentused":
				currentDive.weightKg = Double(text)
			case "airtemperature" where parent == "informationbeforedive":
				currentDive.airTempCelsius = kelvinToCelsius(Double(text))

				// Tank data
			case "tankpressurebegin" where parent == "tankdata":
				currentTank.startPressureBar = Double(text).map { $0 / 100_000 } // Pa to bar
			case "tankpressureend" where parent == "tankdata":
				currentTank.endPressureBar = Double(text).map { $0 / 100_000 } // Pa to bar
			case "tankdata":
				currentDive.tanks.append(currentTank)

				// Waypoints
			case "depth" where parent == "waypoint":
				currentWaypoint.depth = Double(text) ?? 0
			case "divetime" where parent == "waypoint":
				currentWaypoint.divetime = Double(text) ?? 0
			case "temperature" where parent == "waypoint":
				currentWaypoint.temperatureCelsius = kelvinToCelsius(Double(text))
			case "tankpressure" where parent == "waypoint":
				if let pa = Double(text) {
					let bar = pa / 100_000
					if currentTankPressureIndex <= 1 {
						currentWaypoint.tankPressureBar = bar
					} else {
						currentWaypoint.tank2PressureBar = bar
					}
				}
			case "measuredpo2" where parent == "waypoint":
				if let pa = Double(text) {
					let bar = pa / 100_000
					switch currentPO2SensorIndex {
						case 1:  currentWaypoint.ppo2Bar = bar
						case 2:  currentWaypoint.ppo2Sensor2Bar = bar
						default: currentWaypoint.ppo2Sensor3Bar = bar
					}
				}
			case "calculatedpo2" where parent == "waypoint":
				if let pa = Double(text) {
					currentWaypoint.calculatedPpo2Bar = pa / 100_000
				}
			case "setpo2" where parent == "waypoint":
				if let pa = Double(text) {
					currentWaypoint.setpointBar = pa / 100_000
				}
			case "cns" where parent == "waypoint":
				currentWaypoint.cnsPercent = Double(text)
			case "nodecotime" where parent == "waypoint":
				if let seconds = Double(text) {
					currentWaypoint.nodecoTimeSeconds = Int(seconds)
				}
			case "remainingbottomtime" where parent == "waypoint":
				if let seconds = Double(text) {
					currentWaypoint.rbtSeconds = Int(seconds)
				}
			case "heading" where parent == "waypoint":
				if let degrees = Double(text) {
					currentWaypoint.headingDegrees = Int(degrees)
				}
			case "pulserate" where parent == "waypoint":
				currentWaypoint.heartbeatBPM = Int(Double(text) ?? 0)
			case "heartrate" where parent == "waypoint":
				if let bpm = Double(text) {
					currentWaypoint.heartbeatBPM = Int(bpm)
				}
			case "alarm" where parent == "waypoint":
				if !text.isEmpty {
					currentWaypoint.alarms.append(text)
				}
			case "waypoint":
				currentDive.waypoints.append(currentWaypoint)

				// Information after dive
			case "greatestdepth" where parent == "informationafterdive":
				currentDive.greatestDepth = Double(text)
			case "diveduration" where parent == "informationafterdive":
				currentDive.diveDuration = Int(Double(text) ?? 0)
			case "lowesttemperature" where parent == "informationafterdive":
				currentDive.lowestTempCelsius = kelvinToCelsius(Double(text))
			case "visibility" where parent == "informationafterdive":
				currentDive.visibilityMeters = Double(text)
			case "ratingvalue":
				currentDive.rating = Int(Double(text) ?? 3)
			case "notes" where parent == "informationafterdive":
				if !text.isEmpty && (currentDive.notes ?? "").isEmpty { currentDive.notes = text }
			case "notes" where (parent == "trippart" || parent == "trip") && insideDiveTrip:
				if !text.isEmpty && (currentTrip.notes ?? "").isEmpty { currentTrip.notes = text }
			case "para" where elementStack.contains("notes") && insideDiveTrip:
				// Nil vs empty distinguishes "no paras seen yet" from "first para
				// was empty" so leading blank lines round-trip correctly.
				if let existing = currentTrip.notes {
					currentTrip.notes = existing + "\n" + text
				} else {
					currentTrip.notes = text
				}
			case "para" where elementStack.contains("notes"):
				if let existing = currentDive.notes {
					currentDive.notes = existing + "\n" + text
				} else {
					currentDive.notes = text
				}

				// End of dive
			case "dive":
				result.dives.append(currentDive)

				// End of trip
			case "trip" where insideDiveTrip:
				result.trips.append(currentTrip)
				insideDiveTrip = false

			case "divetrip":
				break

			default:
				if handlePersonEnd(elementName, parent: parent, text: text) { break }
				if handleEquipmentEnd(elementName, parent: parent, text: text) { break }
		}

		elementStack.removeLast()
	}

	/// Applies the owner and buddy name, address, and contact elements.
	///
	/// Split out of `parser(_:didEndElement:…)` to keep that switch a workable
	/// size. Called from its `default:` branch, so any case declared there still
	/// takes precedence — several element names are shared with other sections.
	private func handlePersonEnd(_ elementName: String, parent: String, text: String) -> Bool {
		switch elementName {
				// Owner — personal
			case "firstname" where isInsideOwner():
				currentOwner.firstName = text
			case "lastname" where isInsideOwner():
				currentOwner.lastName = text

				// Owner — address
			case "street" where isInsideOwnerAddress():
				currentOwner.street = text
			case "city" where isInsideOwnerAddress():
				currentOwner.city = text
			case "state" where isInsideOwnerAddress():
				currentOwner.state = text
			case "province" where isInsideOwnerAddress():
				currentOwner.province = text
			case "postcode" where isInsideOwnerAddress():
				currentOwner.postalCode = text
			case "country" where isInsideOwnerAddress():
				currentOwner.country = text

				// Owner — contact
			case "phone" where isInsideOwnerContact():
				currentOwner.telephone = text
			case "telephone" where isInsideOwnerContact():
				currentOwner.telephone = text
			case "email" where isInsideOwnerContact():
				currentOwner.email = text
			case "homepage" where isInsideOwnerContact():
				currentOwner.webPage = text

			case "owner" where parent == "diver":
				result.owner = currentOwner
				insideOwner = false

				// Buddy — personal
			case "firstname" where isInsideBuddy():
				currentBuddy.firstName = text
			case "lastname" where isInsideBuddy():
				currentBuddy.lastName = text

				// Buddy — address
			case "street" where isInsideBuddyAddress():
				currentBuddy.street = text
			case "city" where isInsideBuddyAddress():
				currentBuddy.city = text
			case "state" where isInsideBuddyAddress():
				currentBuddy.state = text
			case "province" where isInsideBuddyAddress():
				currentBuddy.province = text
			case "postcode" where isInsideBuddyAddress():
				currentBuddy.postalCode = text
			case "country" where isInsideBuddyAddress():
				currentBuddy.country = text

				// Buddy — contact
			case "phone" where isInsideBuddyContact():
				currentBuddy.telephone = text
			case "telephone" where isInsideBuddyContact():
				currentBuddy.telephone = text
			case "email" where isInsideBuddyContact():
				currentBuddy.email = text
			case "homepage" where isInsideBuddyContact():
				currentBuddy.webPage = text

			case "buddy" where parent == "diver":
				if let id = currentBuddyId {
					result.buddies[id] = currentBuddy
				}
			default:
				return false
		}
		return true
	}

	/// Applies the fields of the equipment piece currently being parsed.
	///
	/// Split out of `parser(_:didEndElement:…)` to keep that switch a workable
	/// size. Called from its `default:` branch, so any case declared there still
	/// takes precedence — several element names are shared with other sections.
	private func handleEquipmentEnd(_ elementName: String, parent: String, text: String) -> Bool {
		switch elementName {
				// Equipment fields
			case "name" where currentEquipmentTag != nil && parent == currentEquipmentTag:
				currentEquipment?.name = text
				// manufacturerType carries its value in a <name> child, not as text.
			case "name" where parent == "manufacturer" && isInsideEquipmentPiece():
				currentEquipment?.manufacturer = text
				// camera/videocamera hold their details in a body/lens/housing/flash
				// sub-piece rather than on the element itself.
			case "name" where equipmentSubPieceTags.contains(parent) && isInsideEquipmentPiece():
				if currentEquipment?.name.isEmpty ?? false { currentEquipment?.name = text }
			case "model" where equipmentSubPieceTags.contains(parent) && isInsideEquipmentPiece():
				currentEquipment?.model = text
			case "serialnumber" where equipmentSubPieceTags.contains(parent) && isInsideEquipmentPiece():
				currentEquipment?.serialNumber = text
				// Legacy: older files put the manufacturer name directly in the element.
			case "manufacturer" where currentEquipmentTag != nil && isInsideEquipmentPiece():
				if !text.isEmpty { currentEquipment?.manufacturer = text }
			case "model" where currentEquipmentTag != nil && isInsideEquipmentPiece():
				currentEquipment?.model = text
			case "serialnumber" where currentEquipmentTag != nil && isInsideEquipmentPiece():
				currentEquipment?.serialNumber = text
			case "datetime" where parent == "purchase" && currentEquipmentTag != nil && isInsideEquipmentPiece():
				currentEquipment?.purchaseDate = parseUDDFDate(text)
			case "price" where parent == "purchase" && currentEquipmentTag != nil && isInsideEquipmentPiece():
				currentEquipment?.purchasePrice = Double(text)
			case "datetime" where parent == "nextservicedate" && currentEquipmentTag != nil && isInsideEquipmentPiece():
				currentEquipment?.nextServiceDate = parseUDDFDate(text)
			case "serviceinterval" where currentEquipmentTag != nil && isInsideEquipmentPiece():
				currentEquipment?.serviceIntervalDays = Int(Double(text) ?? 0)

				// End of equipment piece
			case _ where elementName == currentEquipmentTag:
				if let eq = currentEquipment, !eq.name.isEmpty {
					result.equipment.append(eq)
				}
				currentEquipment = nil
				currentEquipmentTag = nil
			default:
				return false
		}
		return true
	}
	func parser(_ parser: XMLParser, foundCharacters string: String) {
		currentText += string
	}

	func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
		parsingError = parseError
	}

	// MARK: - Helpers

	/// The element's `id` attribute with WaterLogged's `xs:ID` prefix removed, so
	/// it matches the `externalId` it was exported from. Ids and refs are both
	/// canonicalized here so they still resolve against each other.
	private func identifier(in attributes: [String: String]) -> String? {
		attributes["id"].map(UDDFIdentifier.externalId(from:))
	}

	private func handleLink(ref: String) {
		let parent = elementStack.count >= 2 ? elementStack[elementStack.count - 2] : ""

		switch parent {
			case "informationbeforedive":
				// Links in informationbeforedive can reference sites or buddies.
				// Store as site ref if it matches a known site, otherwise as buddy ref.
				// If sites haven't been parsed yet (unlikely but possible), we collect
				// all refs and resolve them after parsing completes.
				if result.sites[ref] != nil {
					currentDive.siteRef = ref
				} else {
					currentDive.buddyRefs.append(ref)
				}
			case "equipmentused":
				// Link to a piece of equipment worn on this dive.
				currentDive.equipmentRefs.append(ref)
			case "tankdata":
				// Link to gas mix
				currentTank.mixRef = ref
			case "relateddives":
				currentTrip.diveRefs.append(ref)
			default:
				break
		}
	}

	private func isInsideSiteGeography() -> Bool {
		elementStack.contains("geography") && elementStack.contains("site")
	}

	private func isInsideDiveTripGeography() -> Bool {
		insideDiveTrip && elementStack.contains("geography") && elementStack.contains("trip")
	}

	private func isInsideOwner() -> Bool {
		insideOwner && elementStack.contains("owner") && elementStack.contains("diver")
	}

	private func isInsideOwnerAddress() -> Bool {
		elementStack.contains("address") && isInsideOwner()
	}

	private func isInsideOwnerContact() -> Bool {
		elementStack.contains("contact") && isInsideOwner()
	}

	private func isInsideBuddy() -> Bool {
		!insideOwner && elementStack.contains("buddy") && elementStack.contains("diver")
	}

	private func isInsideBuddyAddress() -> Bool {
		elementStack.contains("address") && isInsideBuddy()
	}

	private func isInsideBuddyContact() -> Bool {
		elementStack.contains("contact") && isInsideBuddy()
	}

	/// Sub-pieces of `cameraType`/`videocameraType`, which hold the details that
	/// other equipment kinds carry directly on the element.
	private let equipmentSubPieceTags: Set<String> = ["body", "lens", "housing", "flash", "light"]

	private func isInsideEquipmentPiece() -> Bool {
		guard let tag = currentEquipmentTag else { return false }
		return elementStack.contains(tag) && elementStack.contains("equipment")
	}

	private func kelvinToCelsius(_ kelvin: Double?) -> Double? {
		guard let k = kelvin, k > 0 else { return nil }
		// Some exporters use Celsius directly if values are below 100
		if k < 200 { return k }
		return k - 273.15
	}

	private func parseUDDFDate(_ string: String) -> Date? {
		// UDDF uses ISO 8601: "2006-04-28T08:15:00" or "2006-04-28T08:15"
		// If an explicit timezone is present (e.g. "Z" or "+05:00"), respect it.
		let formatter = ISO8601DateFormatter()
		formatter.formatOptions = [.withInternetDateTime]
		if let date = formatter.date(from: string) {
			return date
		}
		// No timezone in the string — interpret as local time at the dive site.
		// Most UDDF exporters write the dive computer's local time without a
		// timezone indicator, so we parse in the user's current timezone to
		// preserve the original wall-clock time on display.
		formatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
		formatter.timeZone = .current
		if let date = formatter.date(from: string) {
			return date
		}
		// Fallback: manual parsing for "YYYY-MM-DDThh:mm" format
		let df = DateFormatter()
		df.locale = Locale(identifier: "en_US_POSIX")
		df.timeZone = .current
		for format in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd"] {
			df.dateFormat = format
			if let date = df.date(from: string) {
				return date
			}
		}
		return nil
	}
}
