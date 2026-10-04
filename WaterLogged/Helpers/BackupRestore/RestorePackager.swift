//
//  RestorePackager.swift
//  WaterLogged
//
//  Created by John Meyer on 4/27/26.
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

/// Restores a complete WaterLogged backup archive, replacing all existing data.
///
/// The archive is expected to contain:
/// - `logbook.uddf` — UDDF 3.2.2 file with standard dive data
/// - `extras.xml` — WaterLogged-proprietary XML for fields not in UDDF
/// - `media/` — images (dive photos, logbook scans, signatures, equipment/buddy/cert images)
///
/// Entities are cross-referenced by their `externalId` UUIDs: raw in `extras.xml`,
/// and `wl-`-prefixed in the UDDF file (see `UDDFIdentifier`).
struct RestorePackager {

	enum RestoreError: LocalizedError {
		case archiveInvalid(String)
		case importFailed(String)

		var errorDescription: String? {
			switch self {
				case .archiveInvalid(let detail): "Invalid backup archive: \(detail)"
				case .importFailed(let detail): "Restore failed: \(detail)"
			}
		}
	}

	/// A tally of the entities present after a restore. Because a restore
	/// replaces all existing data, these counts reflect the entire restored
	/// log book.
	struct RestoreSummary {
		var dives = 0
		var sites = 0
		var buddies = 0
		var equipment = 0
		var gasMixes = 0
		var certifications = 0
		var trips = 0

		/// A human-readable summary of what was restored, for display after the
		/// operation completes.
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
			add(gasMixes, singular: "gas mix", plural: "gas mixes")
			add(certifications, singular: "certification", plural: "certifications")
			add(trips, singular: "trip", plural: "trips")

			guard !parts.isEmpty else {
				return "Restore complete, but the archive contained no data."
			}
			return "Restored \(parts.formatted(.list(type: .and)))."
		}
	}

	/// Restores the backup archive, replacing all existing logbook data.
	/// Returns a summary of the restored entity counts.
	///
	/// All or nothing: the archive is fully parsed before anything is deleted,
	/// and the replacement is committed by a single save. If the restore fails
	/// at any point, the existing logbook is left unchanged.
	///
	/// - Parameter workingDirectory: Scratch directory into which the archive is
	///   extracted. Defaults to the system temporary directory; tests inject an
	///   isolated, self-cleaning directory.
	@discardableResult
	static func restoreArchive(
		at url: URL,
		into context: ModelContext,
		workingDirectory: URL = .temporaryDirectory
	) throws -> RestoreSummary {
		let accessing = url.startAccessingSecurityScopedResource()
		defer { if accessing { url.stopAccessingSecurityScopedResource() } }

		// 1. Extract zip to a temporary directory
		let tempDir = workingDirectory.appending(path: "WaterLogged_Restore_\(UUID().uuidString)")
		defer { try? FileManager.default.removeItem(at: tempDir) }
		try ZipReader.extractArchive(at: url, to: tempDir)

		// 2. Locate the archive root (may be nested in a single subdirectory)
		let archiveRoot = try findArchiveRoot(in: tempDir)

		let uddfURL = archiveRoot.appending(path: "logbook.uddf")
		guard FileManager.default.fileExists(atPath: uddfURL.path()) else {
			throw RestoreError.archiveInvalid("Missing logbook.uddf in archive.")
		}

		// 3. Parse both documents before making any database changes, so a
		//    damaged archive fails while the existing logbook is untouched.
		let parsedLogbook = try UDDFImporter.parse(data: Data(contentsOf: uddfURL))

		let extrasURL = archiveRoot.appending(path: "extras.xml")
		var extras: ParsedExtras?
		if FileManager.default.fileExists(atPath: extrasURL.path()) {
			extras = try ExtrasParser.parse(contentsOf: extrasURL)
		}

		let mediaDir = archiveRoot.appending(path: "media")

		// 4–6. Replace the logbook as a single transaction: the deletions, the
		//      import and the extras are committed by one save. If any step
		//      throws, the pending changes are rolled back and the existing data
		//      is left exactly as it was.
		do {
			try deleteAllData(from: context)
			try UDDFImporter.importParsed(parsedLogbook, into: context, shouldSave: false)
			if let extras {
				try applyExtras(extras, to: context, mediaDir: mediaDir)
			}
			try context.save()
		} catch {
			context.rollback()
			throw error
		}

		// Tally the persisted entities. A restore replaces all existing data,
		// so these counts describe the entire restored log book — including gas
		// mixes, which are created on demand while mapping tanks and so are not
		// tracked by the UDDF importer's summary.
		return RestoreSummary(
			dives: try context.fetchCount(FetchDescriptor<Dive>()),
			sites: try context.fetchCount(FetchDescriptor<DiveSite>()),
			buddies: try context.fetchCount(FetchDescriptor<Buddy>()),
			equipment: try context.fetchCount(FetchDescriptor<Equipment>()),
			gasMixes: try context.fetchCount(FetchDescriptor<GasMix>()),
			certifications: try context.fetchCount(FetchDescriptor<Certification>()),
			trips: try context.fetchCount(FetchDescriptor<Trip>())
		)
	}

	// MARK: - Archive Root Discovery

	/// The zip may contain files directly or nested inside a single directory
	/// (as produced by NSFileCoordinator's `.forUploading` option).
	private static func findArchiveRoot(in directory: URL) throws -> URL {
		let fm = FileManager.default

		if fm.fileExists(atPath: directory.appending(path: "logbook.uddf").path()) {
			return directory
		}

		let contents = try fm.contentsOfDirectory(
			at: directory,
			includingPropertiesForKeys: [.isDirectoryKey]
		)
		for item in contents {
			let values = try item.resourceValues(forKeys: [.isDirectoryKey])
			if values.isDirectory == true,
			   fm.fileExists(atPath: item.appending(path: "logbook.uddf").path()) {
				return item
			}
		}

		throw RestoreError.archiveInvalid("Could not find logbook.uddf in the archive.")
	}

	// MARK: - Delete All Data

	/// Marks every model instance for deletion, without saving — the caller
	/// commits the deletions together with the restored data.
	///
	/// Each model is deleted individually rather than with the batch
	/// `delete(model:)`: individual deletions are ordinary tracked changes that
	/// CloudKit mirroring propagates to the user's other devices, and they can't
	/// sweep up the restored records the way a batch delete evaluated at save
	/// time could.
	private static func deleteAllData(from context: ModelContext) throws {
		func deleteAll<T: PersistentModel>(_ type: T.Type) throws {
			for model in try context.fetch(FetchDescriptor<T>()) {
				context.delete(model)
			}
		}
		try deleteAll(Dive.self)
		try deleteAll(DiveSite.self)
		try deleteAll(Trip.self)
		try deleteAll(Equipment.self)
		try deleteAll(GasMix.self)
		try deleteAll(Buddy.self)
		try deleteAll(Certification.self)
		try deleteAll(LogbookOwner.self)
		try deleteAll(Photo.self)
		try deleteAll(DepthSample.self)
		try deleteAll(ServiceRecord.self)
		try deleteAll(Tank.self)
	}

	// MARK: - Apply Extras

	private static func applyExtras(
		_ extras: ParsedExtras,
		to context: ModelContext,
		mediaDir: URL
	) throws {
		func readMedia(_ filename: String?) -> Data? {
			guard let filename, !filename.isEmpty else { return nil }
			let fileURL = mediaDir.appending(path: filename)
			return try? Data(contentsOf: fileURL)
		}

		// Dive extras
		if !extras.dives.isEmpty {
			let allDives = try context.fetch(FetchDescriptor<Dive>())
			let divesByID = allDives.keyedByFirst(\.externalId)

			let needsCertLookup = extras.dives.values.contains { $0.certificationExternalId != nil }
			var certsByID: [String: Certification] = [:]
			var certsByMatchKey: [String: Certification] = [:]
			if needsCertLookup {
				let allCerts = try context.fetch(FetchDescriptor<Certification>())
				certsByID = allCerts.keyedByFirst(\.externalId)
				certsByMatchKey = allCerts.keyedByFirst(\.backupMatchKey)
			}

			let needsEquipmentLookup = extras.dives.values.contains {
				!$0.equipmentExternalIds.isEmpty || $0.tanks.contains { $0.equipmentExternalId != nil }
			}
			let equipmentByID: [String: Equipment]
			if needsEquipmentLookup {
				let allEquipment = try context.fetch(FetchDescriptor<Equipment>())
				equipmentByID = allEquipment.keyedByFirst(\.externalId)
			} else {
				equipmentByID = [:]
			}

			for (id, diveExtra) in extras.dives {
				guard let dive = divesByID[id] else { continue }
				if let v = diveExtra.title { dive.title = v }
				if let v = diveExtra.diveGuide { dive.diveGuide = v.isEmpty ? nil : v }
				if let v = diveExtra.diveOperator { dive.diveOperator = v.isEmpty ? nil : v }
				if let v = diveExtra.boat { dive.diveBoat = v.isEmpty ? nil : v }
				if let v = diveExtra.weather { dive.weather = v }
				if let v = diveExtra.waterType { dive.waterType = WaterType(rawValue: v) }
				if let v = diveExtra.current { dive.current = Current(rawValue: v) }
				if let v = diveExtra.waveConditions { dive.waveConditions = WaveConditions(rawValue: v) }
				if let v = diveExtra.suitType { dive.suitType = SuitType(rawValue: v) }
				if let v = diveExtra.weightKg { dive.weightKg = v }
				if let v = diveExtra.startLatitude { dive.startLatitude = v }
				if let v = diveExtra.startLongitude { dive.startLongitude = v }
				if let v = diveExtra.endLatitude { dive.endLatitude = v }
				if let v = diveExtra.endLongitude { dive.endLongitude = v }
				if !diveExtra.tags.isEmpty { dive.tags = diveExtra.tags }
				if let v = diveExtra.importSource { dive.importSource = v }

				dive.logbookImageData = readMedia(diveExtra.logbookImageFile)
				if let v = diveExtra.logbookImageFilename { dive.logbookImageFilename = v }
				dive.verificationSignatureData = readMedia(diveExtra.signatureFile)

				// Prefer the content key; the id only resolves for archives whose
				// UDDF still carried certification ids.
				if let key = diveExtra.certificationMatchKey, let cert = certsByMatchKey[key] {
					dive.certification = cert
				} else if let certID = diveExtra.certificationExternalId {
					dive.certification = certsByID[certID]
				}

				if !diveExtra.equipmentExternalIds.isEmpty {
					dive.equipment = diveExtra.equipmentExternalIds.compactMap { equipmentByID[$0] }
				}

				// Apply TTS data to depth samples
				if !diveExtra.sampleTTS.isEmpty, let samples = dive.diveProfile {
					let samplesByElapsed = Dictionary(
						samples.map { ($0.elapsedSeconds, $0) },
						uniquingKeysWith: { a, _ in a }
					)
					for entry in diveExtra.sampleTTS {
						samplesByElapsed[entry.elapsed]?.decoTTSSeconds = entry.tts
					}
				}

				// Tanks whose gas mix / equipment link couldn't be written to the
				// UDDF file because <tankdata> requires a starting pressure. See
				// BackupPackager.writeUnlinkedTanks.
				for tankExtra in diveExtra.tanks {
					var gasMix: GasMix?
					if let o2 = tankExtra.gasMixOxygenPercent {
						gasMix = GasMix.findOrCreate(
							name: tankExtra.gasMixName ?? "Air",
							oxygenPercent: o2,
							heliumPercent: tankExtra.gasMixHeliumPercent ?? 0,
							argonPercent: tankExtra.gasMixArgonPercent ?? 0,
							hydrogenPercent: tankExtra.gasMixHydrogenPercent ?? 0,
							uddfId: tankExtra.gasMixExternalId,
							in: context
						)
					}
					let equipment = tankExtra.equipmentExternalId.flatMap { equipmentByID[$0] }
					guard gasMix != nil || equipment != nil || tankExtra.endPressureBar != nil else { continue }

					let tank = Tank(gasMix: gasMix, endPressureBar: tankExtra.endPressureBar)
					tank.equipment = equipment
					tank.dive = dive
					context.insert(tank)
				}
			}
		}

		// Equipment extras
		if !extras.equipment.isEmpty {
			let allEquipment = try context.fetch(FetchDescriptor<Equipment>())
			let equipmentByID = allEquipment.keyedByFirst(\.externalId)

			for (id, extra) in extras.equipment {
				guard let item = equipmentByID[id] else { continue }
				if let v = extra.storeName { item.storeName = v }
				if let v = extra.storeURL { item.storeURL = v }
				if let v = extra.warranty { item.warranty = v }
				if let v = extra.notes { item.notes = v }
				if extra.isRetired { item.isRetired = true }
				if extra.autoAddToDives { item.autoAddToDives = true }

				item.photoData = readMedia(extra.photoFile)

				for record in extra.serviceRecords {
					let sr = ServiceRecord(
						serviceDate: record.date,
						servicedBy: record.servicedBy,
						notes: record.notes
					)
					sr.equipment = item
					context.insert(sr)
				}
			}
		}

		// Buddy extras
		if !extras.buddies.isEmpty {
			let allBuddies = try context.fetch(FetchDescriptor<Buddy>())
			let buddiesByID = allBuddies.keyedByFirst(\.externalId)

			for (id, extra) in extras.buddies {
				guard let buddy = buddiesByID[id] else { continue }
				if extra.isRetired { buddy.isRetired = true }
				buddy.photoData = readMedia(extra.photoFile)
			}
		}

		// Certification extras
		if !extras.certifications.isEmpty {
			let allCerts = try context.fetch(FetchDescriptor<Certification>())
			let certsByID = allCerts.keyedByFirst(\.externalId)
			let certsByMatchKey = allCerts.keyedByFirst(\.backupMatchKey)

			for (id, extra) in extras.certifications {
				guard let cert = extra.matchKey.flatMap({ certsByMatchKey[$0] }) ?? certsByID[id] else { continue }
				// The UDDF file cannot carry a certification id, so the imported
				// record has a fresh one. Put the archived externalId back.
				cert.externalId = id
				if let v = extra.certificationNumber { cert.certificationNumber = v }
				if let v = extra.diveShop { cert.diveShop = v }
				if let v = extra.instructorNumber { cert.instructorNumber = v }
				cert.frontImageData = readMedia(extra.frontImageFile)
				cert.backImageData = readMedia(extra.backImageFile)
			}
		}

		// Site extras
		if !extras.sites.isEmpty {
			let allSites = try context.fetch(FetchDescriptor<DiveSite>())
			let sitesByID = allSites.keyedByFirst(\.externalId)

			for (id, extra) in extras.sites {
				guard let site = sitesByID[id] else { continue }
				if let v = extra.notes { site.notes = v }
			}
		}

		// Trip extras
		if !extras.trips.isEmpty {
			let allTrips = try context.fetch(FetchDescriptor<Trip>())
			let tripsByID = allTrips.keyedByFirst(\.externalId)

			for (id, extra) in extras.trips {
				guard let trip = tripsByID[id] else { continue }
				if let v = extra.address { trip.address = v }
				if let v = extra.urlString { trip.urlString = v }
			}
		}

		// Owner extras
		if let ownerExtra = extras.owner {
			if let owner = try? LogbookOwner.fetchOrCreate(in: context) {
				owner.photoData = readMedia(ownerExtra.photoFile)
			}
		}

		// Photo manifest — create Photo model instances and link to parents
		if !extras.photos.isEmpty {
			let allDives = try context.fetch(FetchDescriptor<Dive>())
			let divesByID = allDives.keyedByFirst(\.externalId)
			let allSites = try context.fetch(FetchDescriptor<DiveSite>())
			let sitesByID = allSites.keyedByFirst(\.externalId)
			let allTrips = try context.fetch(FetchDescriptor<Trip>())
			let tripsByID = allTrips.keyedByFirst(\.externalId)

			for entry in extras.photos {
				guard let imageData = readMedia(entry.file) else { continue }

				let photo = Photo(
					imageData: imageData,
					caption: entry.caption,
					sortOrder: entry.sortOrder,
					dateAdded: entry.dateAdded ?? .now,
					originalFilename: entry.originalFilename
				)

				// Link photo to its parent entity; skip orphaned photos
				// that can't be matched to any record.
				var linked = false
				if let diveID = entry.diveExternalId, let dive = divesByID[diveID] {
					photo.dive = dive
					linked = true
				} else if let siteID = entry.siteExternalId, let site = sitesByID[siteID] {
					photo.diveSite = site
					linked = true
				} else if let tripID = entry.tripExternalId, let trip = tripsByID[tripID] {
					photo.trip = trip
					linked = true
				}

				guard linked else { continue }
				context.insert(photo)
			}
		}
	}
}

// MARK: - Parsed Extras Types

private struct ParsedExtras {
	var dives: [String: DiveExtras] = [:]
	var equipment: [String: EquipmentExtras] = [:]
	var buddies: [String: BuddyExtras] = [:]
	var certifications: [String: CertificationExtras] = [:]
	var sites: [String: SiteExtras] = [:]
	var trips: [String: TripExtras] = [:]
	var owner: OwnerExtras?
	var photos: [RestorePhotoEntry] = []
}

private struct DiveExtras {
	var title: String?
	var diveGuide: String?
	var diveOperator: String?
	var boat: String?
	var weather: String?
	var waterType: String?
	var current: String?
	var waveConditions: String?
	var suitType: String?
	var weightKg: Double?
	var startLatitude: Double?
	var startLongitude: Double?
	var endLatitude: Double?
	var endLongitude: Double?
	var tags: [String] = []
	var importSource: String?
	var logbookImageFile: String?
	/// The scan's original file name. Absent in archives written before 2026-08-15.
	var logbookImageFilename: String?
	var signatureFile: String?
	var certificationExternalId: String?
	/// Content key for the linked certification, since UDDF gives certifications
	/// no id of their own. Absent in archives written before that change.
	var certificationMatchKey: String?
	var equipmentExternalIds: [String] = []
	var sampleTTS: [(elapsed: Int, tts: Int)] = []
	/// Tanks that couldn't survive as UDDF `<tankdata>` because they have no
	/// starting pressure. See `BackupPackager.writeUnlinkedTanks`.
	var tanks: [TankExtra] = []
}

private struct TankExtra {
	var gasMixExternalId: String?
	var gasMixName: String?
	var gasMixOxygenPercent: Double?
	var gasMixHeliumPercent: Double?
	var gasMixArgonPercent: Double?
	var gasMixHydrogenPercent: Double?
	var equipmentExternalId: String?
	var endPressureBar: Double?
}

private struct EquipmentExtras {
	var storeName: String?
	var storeURL: String?
	var warranty: String?
	var notes: String?
	var isRetired: Bool = false
	var autoAddToDives: Bool = false
	var photoFile: String?
	var serviceRecords: [(date: Date, servicedBy: String, notes: String)] = []
}

private struct BuddyExtras {
	var isRetired: Bool = false
	var photoFile: String?
}

private struct CertificationExtras {
	/// Content key matching `Certification.backupMatchKey`; absent in older archives.
	var matchKey: String?
	var certificationNumber: String?
	var diveShop: String?
	var instructorNumber: String?
	var frontImageFile: String?
	var backImageFile: String?
}

private struct SiteExtras {
	var notes: String?
}

private struct TripExtras {
	var address: String?
	var urlString: String?
}

private struct OwnerExtras {
	var photoFile: String?
}

private struct RestorePhotoEntry {
	var file: String
	var caption: String = ""
	var sortOrder: Int = 0
	var dateAdded: Date?
	var originalFilename: String = ""
	var diveExternalId: String?
	var siteExternalId: String?
	var tripExternalId: String?
}

// MARK: - Extras XML Parser

/// Parses the `extras.xml` file produced by `BackupPackager`.
private final class ExtrasParser: NSObject, XMLParserDelegate {
	private var result = ParsedExtras()

	private var elementStack: [String] = []
	private var currentText = ""

	// Current objects being built
	private var currentDiveId: String?
	private var currentDiveExtras = DiveExtras()
	private var currentSampleElapsed: Int?
	private var currentTankExtra: TankExtra?

	private var currentEquipmentId: String?
	private var currentEquipmentExtras = EquipmentExtras()
	private var currentServiceDate: Date?
	private var currentServiceBy = ""
	private var currentServiceNotes = ""

	private var currentBuddyId: String?
	private var currentBuddyExtras = BuddyExtras()

	private var currentCertId: String?
	private var currentCertExtras = CertificationExtras()

	private var currentSiteId: String?
	private var currentSiteExtras = SiteExtras()

	private var currentTripId: String?
	private var currentTripExtras = TripExtras()

	private var currentPhotoEntry: RestorePhotoEntry?

	private var parsingError: Error?

	static func parse(contentsOf url: URL) throws -> ParsedExtras {
		let data = try Data(contentsOf: url)
		let parser = ExtrasParser()
		let xmlParser = XMLParser(data: data)
		xmlParser.delegate = parser
		xmlParser.shouldProcessNamespaces = false

		if !xmlParser.parse() {
			// `parsingError` holds XMLParser's raw NSError (captured in
			// parseErrorOccurred). Wrap it rather than rethrowing it, so callers
			// catching RestoreError aren't bypassed by an NSXMLParserErrorDomain
			// NSError leaking out of the restore path.
			let underlying = parser.parsingError ?? xmlParser.parserError
			throw RestorePackager.RestoreError.importFailed(
				underlying?.localizedDescription ?? "Failed to parse extras.xml"
			)
		}
		return parser.result
	}

	// MARK: - XMLParserDelegate

	func parser(
		_ parser: XMLParser,
		didStartElement elementName: String,
		namespaceURI: String?,
		qualifiedName: String?,
		attributes attrs: [String: String]
	) {
		elementStack.append(elementName)
		currentText = ""

		switch elementName {
			case "dive" where elementStack.contains("dives"):
				currentDiveId = attrs["id"]
				currentDiveExtras = DiveExtras()

			case "sample" where elementStack.contains("samples"):
				currentSampleElapsed = attrs["elapsed"].flatMap(Int.init)

			case "tank" where elementStack.contains("tanks") && currentDiveId != nil:
				currentTankExtra = TankExtra()

			case "gasmix" where currentTankExtra != nil:
				currentTankExtra?.gasMixExternalId = attrs["id"]
				currentTankExtra?.gasMixName = attrs["name"]
				currentTankExtra?.gasMixOxygenPercent = attrs["o2"].flatMap(Double.init)
				currentTankExtra?.gasMixHeliumPercent = attrs["he"].flatMap(Double.init)
				currentTankExtra?.gasMixArgonPercent = attrs["ar"].flatMap(Double.init)
				currentTankExtra?.gasMixHydrogenPercent = attrs["h2"].flatMap(Double.init)

			case "equipmentlink" where currentTankExtra != nil:
				currentTankExtra?.equipmentExternalId = attrs["id"]

			case "logbookimage":
				currentDiveExtras.logbookImageFile = attrs["file"]
				currentDiveExtras.logbookImageFilename = attrs["originalfilename"]

			case "signature" where elementStack.contains("dive"):
				currentDiveExtras.signatureFile = attrs["file"]

			case "item" where elementStack.contains("equipment"):
				currentEquipmentId = attrs["id"]
				currentEquipmentExtras = EquipmentExtras()

			case "photo" where elementStack.contains("item"):
				currentEquipmentExtras.photoFile = attrs["file"]

			case "record" where elementStack.contains("servicehistory"):
				currentServiceDate = nil
				currentServiceBy = ""
				currentServiceNotes = ""

			case "buddy" where elementStack.contains("buddies"):
				currentBuddyId = attrs["id"]
				currentBuddyExtras = BuddyExtras()

			case "photo" where elementStack.contains("buddy"):
				currentBuddyExtras.photoFile = attrs["file"]

			case "certification" where elementStack.contains("dives") && currentDiveId != nil:
				currentDiveExtras.certificationExternalId = attrs["id"]
				currentDiveExtras.certificationMatchKey = attrs["matchkey"]

				// Legacy archives only: newer backups carry the dive → equipment links in
				// the UDDF file's <equipmentused> block, which the UDDF import applies.
			case "equipment" where elementStack.contains("equipmentused"):
				if let id = attrs["id"] { currentDiveExtras.equipmentExternalIds.append(id) }

			case "certification" where elementStack.contains("certifications"):
				currentCertId = attrs["id"]
				currentCertExtras = CertificationExtras()
				currentCertExtras.matchKey = attrs["matchkey"]

			case "frontimage":
				currentCertExtras.frontImageFile = attrs["file"]

			case "backimage":
				currentCertExtras.backImageFile = attrs["file"]

			case "site" where elementStack.contains("sites"):
				currentSiteId = attrs["id"]
				currentSiteExtras = SiteExtras()

			case "trip" where elementStack.contains("trips"):
				currentTripId = attrs["id"]
				currentTripExtras = TripExtras()

			case "owner":
				result.owner = OwnerExtras()
				if let file = attrs["file"] {
					result.owner?.photoFile = file
				}

			case "photo" where elementStack.contains("owner"):
				result.owner?.photoFile = attrs["file"]

			case "photo" where elementStack.contains("photos"):
				var entry = RestorePhotoEntry(file: attrs["file"] ?? "")
				entry.caption = attrs["caption"] ?? ""
				entry.sortOrder = attrs["sortorder"].flatMap(Int.init) ?? 0
				entry.dateAdded = attrs["dateadded"].flatMap(ISO8601DateParser.date(from:))
				entry.originalFilename = attrs["originalfilename"] ?? ""
				currentPhotoEntry = entry

			case "dive" where currentPhotoEntry != nil:
				currentPhotoEntry?.diveExternalId = attrs["id"]

			case "site" where currentPhotoEntry != nil:
				currentPhotoEntry?.siteExternalId = attrs["id"]

			case "trip" where currentPhotoEntry != nil:
				currentPhotoEntry?.tripExternalId = attrs["id"]

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

				// Dive extras
			case "title" where parent == "dive" && currentDiveId != nil:
				currentDiveExtras.title = text
			case "diveguide" where parent == "dive":
				currentDiveExtras.diveGuide = text
			case "divemaster" where parent == "dive":
				// Backwards compatibility: read legacy "divemaster" element into diveGuide
				currentDiveExtras.diveGuide = text
			case "operator" where parent == "dive":
				currentDiveExtras.diveOperator = text
			case "boat" where parent == "dive":
				currentDiveExtras.boat = text
			case "weather" where parent == "dive":
				currentDiveExtras.weather = text
			case "watertype":
				currentDiveExtras.waterType = text
			case "current" where parent == "dive":
				currentDiveExtras.current = text
			case "waveconditions":
				currentDiveExtras.waveConditions = text
			case "suittype":
				currentDiveExtras.suitType = text
				// Legacy archives only: newer backups carry the weight in the UDDF file's
				// <equipmentused><leadquantity>, which the UDDF import applies.
			case "weightkg":
				currentDiveExtras.weightKg = Double(text)
			case "startlatitude" where parent == "dive":
				currentDiveExtras.startLatitude = Double(text)
			case "startlongitude" where parent == "dive":
				currentDiveExtras.startLongitude = Double(text)
			case "endlatitude" where parent == "dive":
				currentDiveExtras.endLatitude = Double(text)
			case "endlongitude" where parent == "dive":
				currentDiveExtras.endLongitude = Double(text)
			case "tag" where elementStack.contains("tags"):
				if !text.isEmpty { currentDiveExtras.tags.append(text) }
			case "importsource":
				currentDiveExtras.importSource = text
			case "decotts" where parent == "sample":
				if let elapsed = currentSampleElapsed, let tts = Int(text) {
					currentDiveExtras.sampleTTS.append((elapsed: elapsed, tts: tts))
				}
			case "tankpressureend" where parent == "tank":
				currentTankExtra?.endPressureBar = Double(text)
			case "tank" where parent == "tanks":
				if let tank = currentTankExtra {
					currentDiveExtras.tanks.append(tank)
				}
				currentTankExtra = nil
			case "dive" where parent == "dives":
				if let id = currentDiveId {
					result.dives[id] = currentDiveExtras
				}
				currentDiveId = nil

				// Equipment extras
			case "storename" where parent == "item":
				currentEquipmentExtras.storeName = text
			case "storeurl" where parent == "item":
				currentEquipmentExtras.storeURL = text
			case "warranty" where parent == "item":
				currentEquipmentExtras.warranty = text
			case "notes" where parent == "item":
				currentEquipmentExtras.notes = text
			case "retired" where parent == "item":
				currentEquipmentExtras.isRetired = text == "true"
			case "autoaddtodives":
				currentEquipmentExtras.autoAddToDives = text == "true"
			case "date" where parent == "record":
				currentServiceDate = ISO8601DateParser.date(from: text)
			case "servicedby":
				currentServiceBy = text
			case "notes" where parent == "record":
				currentServiceNotes = text
			case "record" where parent == "servicehistory":
				if let date = currentServiceDate {
					currentEquipmentExtras.serviceRecords.append(
						(date: date, servicedBy: currentServiceBy, notes: currentServiceNotes)
					)
				}
			case "item" where parent == "equipment":
				if let id = currentEquipmentId {
					result.equipment[id] = currentEquipmentExtras
				}
				currentEquipmentId = nil

				// Buddy extras
			case "retired" where parent == "buddy":
				currentBuddyExtras.isRetired = text == "true"
			case "buddy" where parent == "buddies":
				if let id = currentBuddyId {
					result.buddies[id] = currentBuddyExtras
				}
				currentBuddyId = nil

				// Certification extras
			case "certificationnumber":
				currentCertExtras.certificationNumber = text
			case "diveshop":
				currentCertExtras.diveShop = text
			case "instructornumber":
				currentCertExtras.instructorNumber = text
			case "certification" where parent == "certifications":
				if let id = currentCertId {
					result.certifications[id] = currentCertExtras
				}
				currentCertId = nil

				// Site extras
			case "notes" where parent == "site" && currentSiteId != nil:
				currentSiteExtras.notes = text
			case "site" where parent == "sites":
				if let id = currentSiteId {
					result.sites[id] = currentSiteExtras
				}
				currentSiteId = nil

				// Trip extras
			case "address" where parent == "trip":
				currentTripExtras.address = text
			case "url" where parent == "trip":
				currentTripExtras.urlString = text
			case "trip" where parent == "trips":
				if let id = currentTripId {
					result.trips[id] = currentTripExtras
				}
				currentTripId = nil

				// Photo manifest
			case "photo" where parent == "photos":
				if let entry = currentPhotoEntry {
					result.photos.append(entry)
				}
				currentPhotoEntry = nil

			default:
				break
		}

		elementStack.removeLast()
	}

	func parser(_ parser: XMLParser, foundCharacters string: String) {
		currentText += string
	}

	func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
		parsingError = parseError
	}

	// MARK: - Helpers

}
