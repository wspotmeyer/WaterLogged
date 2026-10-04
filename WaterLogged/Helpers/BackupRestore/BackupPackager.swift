//
//  BackupPackager.swift
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

/// Creates a complete WaterLogged export archive containing:
/// - `logbook.uddf` — UDDF 3.2.2 file with all standard dive data
/// - `extras.xml` — WaterLogged-proprietary XML for fields not in UDDF
/// - `media/` — exported images (dive photos, logbook scans, signatures, equipment/buddy/cert images)
///
/// The archive is delivered as a `.zip` file. Entities are cross-referenced by
/// their `externalId` UUIDs: raw in `extras.xml`, and `wl-`-prefixed in the UDDF
/// file (see `UDDFIdentifier`).
struct BackupPackager {

	enum ExportError: LocalizedError {
		case archiveFailed(String)

		var errorDescription: String? {
			switch self {
				case .archiveFailed(let detail): "Failed to create export archive: \(detail)"
			}
		}
	}

	/// Creates the export archive and returns the URL of the resulting `.zip` file.
	///
	/// - Parameter workingDirectory: Scratch directory for the staged export
	///   folder and the resulting archive. Defaults to the system temporary
	///   directory; tests inject an isolated, self-cleaning directory.
	static func createExportArchive(
		from context: ModelContext,
		workingDirectory: URL = .temporaryDirectory
	) throws -> URL {
		let exportName = "WaterLogged_\(XMLBuilder.exportDateStamp())"
		let exportDir = workingDirectory.appending(path: exportName)

		try? FileManager.default.removeItem(at: exportDir)
		try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)

		defer { try? FileManager.default.removeItem(at: exportDir) }

		// 1. Write UDDF
		try UDDFExporter.export(from: context, to: exportDir.appending(path: "logbook.uddf"))

		// 2. Export all media and build the filename manifest
		let manifest = try exportAllMedia(from: context, to: exportDir)

		// 3. Write extras XML (references media filenames from the manifest)
		try writeExtras(from: context, manifest: manifest, to: exportDir.appending(path: "extras.xml"))

		// 4. Create zip archive
		let zipURL = workingDirectory.appending(path: "\(exportName).zip")
		try? FileManager.default.removeItem(at: zipURL)
		try zipDirectory(at: exportDir, to: zipURL)

		return zipURL
	}

	// MARK: - Media Export

	/// Tracks exported media filenames keyed by owner entity identifiers.
	private struct MediaManifest {
		var photoFiles: [PersistentIdentifier: String] = [:]
		var logbookImages: [String: String] = [:]
		var signatureImages: [String: String] = [:]
		var equipmentPhotos: [String: String] = [:]
		var buddyPhotos: [String: String] = [:]
		var certFrontImages: [String: String] = [:]
		var certBackImages: [String: String] = [:]
		var ownerPhoto: String?
	}

	private static func exportAllMedia(from context: ModelContext, to exportDir: URL) throws -> MediaManifest {
		let mediaDir = exportDir.appending(path: "media")
		var manifest = MediaManifest()
		var createdDir = false

		func ensureDir() throws {
			guard !createdDir else { return }
			try FileManager.default.createDirectory(at: mediaDir, withIntermediateDirectories: true)
			createdDir = true
		}

		func writeMedia(_ data: Data, prefix: String) throws -> String {
			try ensureDir()
			let ext = ImageFileHelper.fileExtension(for: data)
			let filename = "\(prefix)_\(UUID().uuidString).\(ext)"
			try data.write(to: mediaDir.appending(path: filename))
			return filename
		}

		// Photo model instances
		let photos = try context.fetch(FetchDescriptor<Photo>())
		for photo in photos {
			guard let data = photo.imageData else { continue }
			let filename = try writeMedia(data, prefix: "photo")
			manifest.photoFiles[photo.persistentModelID] = filename
		}

		// Dive logbook images and signatures
		let dives = try context.fetch(FetchDescriptor<Dive>())
		for dive in dives {
			if let data = dive.logbookImageData {
				manifest.logbookImages[dive.externalId] = try writeMedia(data, prefix: "logbook")
			}
			if let data = dive.verificationSignatureData {
				manifest.signatureImages[dive.externalId] = try writeMedia(data, prefix: "signature")
			}
		}

		// Equipment photos
		let equipment = try context.fetch(FetchDescriptor<Equipment>())
		for item in equipment {
			if let data = item.photoData {
				manifest.equipmentPhotos[item.externalId] = try writeMedia(data, prefix: "equipment")
			}
		}

		// Buddy photos
		let buddies = try context.fetch(FetchDescriptor<Buddy>())
		for buddy in buddies {
			if let data = buddy.photoData {
				manifest.buddyPhotos[buddy.externalId] = try writeMedia(data, prefix: "buddy")
			}
		}

		// Certification images
		let certs = try context.fetch(FetchDescriptor<Certification>())
		for cert in certs {
			if let data = cert.frontImageData {
				manifest.certFrontImages[cert.externalId] = try writeMedia(data, prefix: "cert_front")
			}
			if let data = cert.backImageData {
				manifest.certBackImages[cert.externalId] = try writeMedia(data, prefix: "cert_back")
			}
		}

		// Owner photo
		if let owner = try? LogbookOwner.fetchOrCreate(in: context), let data = owner.photoData {
			manifest.ownerPhoto = try writeMedia(data, prefix: "owner")
		}

		return manifest
	}

	// MARK: - Extras XML

	private static func writeExtras(
		from context: ModelContext,
		manifest: MediaManifest,
		to url: URL
	) throws {
		let dives = try context.fetch(FetchDescriptor<Dive>(sortBy: [SortDescriptor(\.date)]))
		let equipment = try context.fetch(FetchDescriptor<Equipment>())
		let buddies = try context.fetch(FetchDescriptor<Buddy>())
		let certifications = try context.fetch(FetchDescriptor<Certification>())
		let sites = try context.fetch(FetchDescriptor<DiveSite>())
		let trips = try context.fetch(FetchDescriptor<Trip>())
		let photos = try context.fetch(FetchDescriptor<Photo>())
		let owner = try? LogbookOwner.fetchOrCreate(in: context)

		// Samples are fetched directly rather than through `dive.diveProfile` —
		// see the faulting workaround described on `DepthSample.groupedByDive(in:)`.
		let samplesByDive = try DepthSample.groupedByDive(in: context)

		var xml = XMLBuilder()
		xml.rawLine("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
		xml.open("waterlogged-extras", attributes: [("version", "1.0")])

		writeDiveExtras(&xml, dives: dives, manifest: manifest, samplesByDive: samplesByDive)
		writeEquipmentExtras(&xml, equipment: equipment, manifest: manifest)
		writeBuddyExtras(&xml, buddies: buddies, manifest: manifest)
		writeCertificationExtras(&xml, certifications: certifications, manifest: manifest)
		writeSiteExtras(&xml, sites: sites)
		writeTripExtras(&xml, trips: trips)
		writeOwnerExtras(&xml, owner: owner, manifest: manifest)
		writePhotoManifest(&xml, photos: photos, manifest: manifest)

		xml.close("waterlogged-extras")
		try xml.result.write(to: url, atomically: true, encoding: .utf8)
	}

	// MARK: Dive Extras

	private static func writeDiveExtras(
		_ xml: inout XMLBuilder,
		dives: [Dive],
		manifest: MediaManifest,
		samplesByDive: [PersistentIdentifier: [DepthSample]]
	) {
		// Every dive is written, even one with no other extras, because the
		// entry always carries its importSource.
		guard !dives.isEmpty else { return }

		xml.open("dives")
		for dive in dives {
			xml.open("dive", attributes: [("id", dive.externalId)])

			if !dive.title.isEmpty { xml.element("title", value: dive.title) }
			if let dg = dive.diveGuide, !dg.isEmpty { xml.element("diveguide", value: dg) }
			if let op = dive.diveOperator, !op.isEmpty { xml.element("operator", value: op) }
			if let boat = dive.diveBoat, !boat.isEmpty { xml.element("boat", value: boat) }
			if !dive.weather.isEmpty { xml.element("weather", value: dive.weather) }
			if let wt = dive.waterType { xml.element("watertype", value: wt.rawValue) }
			if let c = dive.current { xml.element("current", value: c.rawValue) }
			if let wc = dive.waveConditions { xml.element("waveconditions", value: wc.rawValue) }
			if let st = dive.suitType { xml.element("suittype", value: st.rawValue) }
			// Weight carried is not written here: it belongs to the UDDF file as
			// <equipmentused><leadquantity>. Older archives still have it here,
			// and RestorePackager still reads those.

			if let v = dive.startLatitude { xml.element("startlatitude", value: XMLBuilder.formatDecimal(v)) }
			if let v = dive.startLongitude { xml.element("startlongitude", value: XMLBuilder.formatDecimal(v)) }
			if let v = dive.endLatitude { xml.element("endlatitude", value: XMLBuilder.formatDecimal(v)) }
			if let v = dive.endLongitude { xml.element("endlongitude", value: XMLBuilder.formatDecimal(v)) }

			if !dive.tags.isEmpty {
				xml.open("tags")
				for tag in dive.tags { xml.element("tag", value: tag) }
				xml.close("tags")
			}

			xml.element("importsource", value: dive.importSource)

			if let file = manifest.logbookImages[dive.externalId] {
				// originalfilename is the name the user's scan came in under; it
				// drives the ShareLink filename in DiveDetailView.
				var attrs: [(String, String)] = [("file", file)]
				if !dive.logbookImageFilename.isEmpty {
					attrs.append(("originalfilename", dive.logbookImageFilename))
				}
				xml.selfClosing("logbookimage", attributes: attrs)
			}
			if let file = manifest.signatureImages[dive.externalId] {
				xml.selfClosing("signature", attributes: [("file", file)])
			}

			if let cert = dive.certification {
				// matchkey is how this survives a round trip: UDDF certifications
				// carry no id, so the restored certification has a new externalId.
				xml.selfClosing("certification", attributes: [
					("id", cert.externalId),
					("matchkey", cert.backupMatchKey)
				])
			}

			// The dive → equipment association is not written here: it belongs to
			// the UDDF file as <informationbeforedive><equipmentused>, which
			// UDDFExporter now writes and UDDFImporter reads back. Archives made
			// before that change still carry it here, and RestorePackager still
			// reads those.

			// Depth sample extras (decoTTSSeconds only — other fields are in the UDDF)
			let diveSamples = samplesByDive[dive.persistentModelID] ?? []
			let ttsEntries = diveSamples
				.compactMap { sample in sample.decoTTSSeconds.map { (elapsed: sample.elapsedSeconds, tts: $0) } }
				.sorted { $0.elapsed < $1.elapsed }
			if !ttsEntries.isEmpty {
				xml.open("samples")
				for entry in ttsEntries {
					xml.open("sample", attributes: [("elapsed", "\(entry.elapsed)")])
					xml.element("decotts", value: "\(entry.tts)")
					xml.close("sample")
				}
				xml.close("samples")
			}

			writeUnlinkedTanks(&xml, dive: dive)

			xml.close("dive")
		}
		xml.close("dives")
	}

	/// Writes tanks whose gas mix / equipment link couldn't be written to the
	/// UDDF file because a `<tankdata>` element requires a starting pressure
	/// (see `UDDFExporter.writeTankData`). Without this, a tank logged with a
	/// gas mix but no recorded pressure would silently lose its dive
	/// association on restore, undercounting that gas mix's dive history.
	private static func writeUnlinkedTanks(_ xml: inout XMLBuilder, dive: Dive) {
		let unlinked = (dive.tanks ?? []).filter { $0.startPressureBar == nil }
		let relevant = unlinked.filter { $0.gasMix != nil || $0.equipment != nil || $0.endPressureBar != nil }
		guard !relevant.isEmpty else { return }

		xml.open("tanks")
		for tank in relevant {
			xml.open("tank")
			if let gas = tank.gasMix {
				xml.selfClosing("gasmix", attributes: [
					("id", gas.externalId),
					("name", gas.name),
					("o2", XMLBuilder.formatDecimal(gas.oxygenPercent)),
					("he", XMLBuilder.formatDecimal(gas.heliumPercent)),
					("ar", XMLBuilder.formatDecimal(gas.argonPercent)),
					("h2", XMLBuilder.formatDecimal(gas.hydrogenPercent))
				])
			}
			if let equipment = tank.equipment {
				xml.selfClosing("equipmentlink", attributes: [("id", equipment.externalId)])
			}
			if let end = tank.endPressureBar {
				xml.element("tankpressureend", value: XMLBuilder.formatDecimal(end))
			}
			xml.close("tank")
		}
		xml.close("tanks")
	}

	// MARK: Equipment Extras

	private static func writeEquipmentExtras(
		_ xml: inout XMLBuilder,
		equipment: [Equipment],
		manifest: MediaManifest
	) {
		let filtered = equipment.filter { equipmentHasExtras($0, manifest: manifest) }
		guard !filtered.isEmpty else { return }

		xml.open("equipment")
		for item in filtered {
			xml.open("item", attributes: [("id", item.externalId)])

			if !item.storeName.isEmpty { xml.element("storename", value: item.storeName) }
			if !item.storeURL.isEmpty { xml.element("storeurl", value: item.storeURL) }
			if !item.warranty.isEmpty { xml.element("warranty", value: item.warranty) }
			if !item.notes.isEmpty { xml.element("notes", value: item.notes) }
			if item.isRetired { xml.element("retired", value: "true") }
			if item.autoAddToDives { xml.element("autoaddtodives", value: "true") }

			if let file = manifest.equipmentPhotos[item.externalId] {
				xml.selfClosing("photo", attributes: [("file", file)])
			}

			if let records = item.serviceHistory, !records.isEmpty {
				xml.open("servicehistory")
				for record in records.sorted(by: { $0.serviceDate < $1.serviceDate }) {
					xml.open("record")
					xml.element("date", value: XMLBuilder.formatISO8601Date(record.serviceDate))
					if !record.servicedBy.isEmpty { xml.element("servicedby", value: record.servicedBy) }
					if !record.notes.isEmpty { xml.element("notes", value: record.notes) }
					xml.close("record")
				}
				xml.close("servicehistory")
			}

			xml.close("item")
		}
		xml.close("equipment")
	}

	private static func equipmentHasExtras(_ item: Equipment, manifest: MediaManifest) -> Bool {
		!item.storeName.isEmpty || !item.storeURL.isEmpty || !item.warranty.isEmpty
		|| !item.notes.isEmpty || item.isRetired || item.autoAddToDives
		|| manifest.equipmentPhotos[item.externalId] != nil
		|| !(item.serviceHistory?.isEmpty ?? true)
	}

	// MARK: Buddy Extras

	private static func writeBuddyExtras(
		_ xml: inout XMLBuilder,
		buddies: [Buddy],
		manifest: MediaManifest
	) {
		let filtered = buddies.filter { $0.isRetired || manifest.buddyPhotos[$0.externalId] != nil }
		guard !filtered.isEmpty else { return }

		xml.open("buddies")
		for buddy in filtered {
			xml.open("buddy", attributes: [("id", buddy.externalId)])
			if buddy.isRetired { xml.element("retired", value: "true") }
			if let file = manifest.buddyPhotos[buddy.externalId] {
				xml.selfClosing("photo", attributes: [("file", file)])
			}
			xml.close("buddy")
		}
		xml.close("buddies")
	}

	// MARK: Certification Extras

	private static func writeCertificationExtras(
		_ xml: inout XMLBuilder,
		certifications: [Certification],
		manifest: MediaManifest
	) {
		let filtered = certifications.filter { certHasExtras($0, manifest: manifest) }
		guard !filtered.isEmpty else { return }

		xml.open("certifications")
		for cert in filtered {
			xml.open("certification", attributes: [
				("id", cert.externalId),
				("matchkey", cert.backupMatchKey)
			])

			if !cert.certificationNumber.isEmpty { xml.element("certificationnumber", value: cert.certificationNumber) }
			if !cert.diveShop.isEmpty { xml.element("diveshop", value: cert.diveShop) }
			if !cert.instructorNumber.isEmpty { xml.element("instructornumber", value: cert.instructorNumber) }

			if let file = manifest.certFrontImages[cert.externalId] {
				xml.selfClosing("frontimage", attributes: [("file", file)])
			}
			if let file = manifest.certBackImages[cert.externalId] {
				xml.selfClosing("backimage", attributes: [("file", file)])
			}

			xml.close("certification")
		}
		xml.close("certifications")
	}

	private static func certHasExtras(_ cert: Certification, manifest: MediaManifest) -> Bool {
		!cert.certificationNumber.isEmpty || !cert.diveShop.isEmpty || !cert.instructorNumber.isEmpty
		|| manifest.certFrontImages[cert.externalId] != nil
		|| manifest.certBackImages[cert.externalId] != nil
	}

	// MARK: Site Extras

	private static func writeSiteExtras(_ xml: inout XMLBuilder, sites: [DiveSite]) {
		let filtered = sites.filter { !$0.notes.isEmpty }
		guard !filtered.isEmpty else { return }

		xml.open("sites")
		for site in filtered {
			xml.open("site", attributes: [("id", site.externalId)])
			xml.element("notes", value: site.notes)
			xml.close("site")
		}
		xml.close("sites")
	}

	// MARK: Trip Extras

	private static func writeTripExtras(_ xml: inout XMLBuilder, trips: [Trip]) {
		let filtered = trips.filter { !$0.address.isEmpty || !$0.urlString.isEmpty }
		guard !filtered.isEmpty else { return }

		xml.open("trips")
		for trip in filtered {
			xml.open("trip", attributes: [("id", trip.externalId)])
			if !trip.address.isEmpty { xml.element("address", value: trip.address) }
			if !trip.urlString.isEmpty { xml.element("url", value: trip.urlString) }
			xml.close("trip")
		}
		xml.close("trips")
	}

	// MARK: Owner Extras

	private static func writeOwnerExtras(
		_ xml: inout XMLBuilder,
		owner: LogbookOwner?,
		manifest: MediaManifest
	) {
		guard let file = manifest.ownerPhoto else { return }
		guard let owner else { return }
		xml.open("owner", attributes: [("id", owner.externalId)])
		xml.selfClosing("photo", attributes: [("file", file)])
		xml.close("owner")
	}

	// MARK: Photo Manifest

	private static func writePhotoManifest(
		_ xml: inout XMLBuilder,
		photos: [Photo],
		manifest: MediaManifest
	) {
		let exported = photos.filter { manifest.photoFiles[$0.persistentModelID] != nil }
		guard !exported.isEmpty else { return }

		xml.open("photos")
		for photo in exported {
			guard let filename = manifest.photoFiles[photo.persistentModelID] else { continue }

			var attrs: [(String, String)] = [("file", filename)]
			if !photo.caption.isEmpty { attrs.append(("caption", photo.caption)) }
			attrs.append(("sortorder", "\(photo.sortOrder)"))
			attrs.append(("dateadded", XMLBuilder.formatISO8601Date(photo.dateAdded)))
			if !photo.originalFilename.isEmpty { attrs.append(("originalfilename", photo.originalFilename)) }

			xml.open("photo", attributes: attrs)
			if let dive = photo.dive { xml.selfClosing("dive", attributes: [("id", dive.externalId)]) }
			if let site = photo.diveSite { xml.selfClosing("site", attributes: [("id", site.externalId)]) }
			if let trip = photo.trip { xml.selfClosing("trip", attributes: [("id", trip.externalId)]) }
			xml.close("photo")
		}
		xml.close("photos")
	}

	// MARK: - Zip Archive

	private static func zipDirectory(at sourceURL: URL, to destinationURL: URL) throws {
		var coordinatorError: NSError?
		var copyError: Error?

		let coordinator = NSFileCoordinator()
		coordinator.coordinate(
			readingItemAt: sourceURL,
			options: .forUploading,
			error: &coordinatorError
		) { zipURL in
			do {
				try FileManager.default.copyItem(at: zipURL, to: destinationURL)
			} catch {
				copyError = error
			}
		}

		if let error = coordinatorError {
			throw ExportError.archiveFailed(error.localizedDescription)
		}
		if let error = copyError {
			throw ExportError.archiveFailed(error.localizedDescription)
		}
	}
}
