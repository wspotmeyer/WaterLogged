//
//  BackupFixtures.swift
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
import SwiftData
@testable import WaterLogged

/// Distinctive image byte blobs whose leading bytes match the signatures that
/// `ImageFileHelper.fileExtension(for:)` detects. Content beyond the magic bytes
/// is arbitrary but stable, so photo round-trips can compare raw bytes.
///
/// `nonisolated` so the constants can be used from a parameterized test's
/// `arguments:` list, which the `@Test` macro evaluates outside the main actor.
nonisolated enum ImageBytes {
	static let jpeg = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01])
	static let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D])
	static let gif = Data([0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00, 0x01, 0x00, 0x80, 0x00])
	static let tiffII = Data([0x49, 0x49, 0x2A, 0x00, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
	static let tiffMM = Data([0x4D, 0x4D, 0x00, 0x2A, 0x00, 0x00, 0x00, 0x08, 0x00, 0x00, 0x00, 0x00])
	static let heic = Data([0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x63])
	/// 12 bytes matching no known signature — expected to default to "jpg".
	static let unknown = Data([0x00, 0x01, 0x02, 0x03, 0x10, 0x11, 0x12, 0x13, 0x20, 0x21, 0x22, 0x23])
	/// Fewer than 12 bytes — expected to default to "jpg".
	static let tooShort = Data([0x89, 0x50, 0x4E])

	/// A JPEG-signatured blob with a unique tail, for media slots that would
	/// otherwise reuse an existing constant. Every media slot in
	/// `FullLogbook.seed` gets distinct bytes so a round-trip that restores the
	/// right data into the WRONG slot still fails.
	static func distinctJPEG(marker: UInt8) -> Data {
		jpeg + Data([marker, marker, marker, marker])
	}
}

/// Builds raw ZIP archives byte-by-byte so tests can construct both valid and
/// deliberately corrupt archives without any real files. Supports only the
/// "stored" (uncompressed, method 0) layout plus an arbitrary method override
/// for exercising `ZipReader`'s error paths.
enum RawZip {

	struct Entry {
		var name: String
		var data: Data
		/// Compression method written into the headers. `ZipReader` supports 0
		/// (stored) and 8 (deflate); other values must trigger an error.
		var method: UInt16 = 0
		/// The bytes physically stored for the entry. Defaults to `data` (stored
		/// layout); override to plant invalid deflate payloads.
		var storedBytes: Data?
	}

	/// Assembles a ZIP archive from the given entries.
	static func make(_ entries: [Entry]) -> Data {
		var output = Data()
		var central = Data()

		for entry in entries {
			let nameBytes = Array(entry.name.utf8)
			let payload = entry.storedBytes ?? entry.data
			let localOffset = UInt32(output.count)

			// Local file header
			output.appendUInt32(0x0403_4b50)
			output.appendUInt16(20)                     // version needed
			output.appendUInt16(0)                      // flags
			output.appendUInt16(entry.method)           // method
			output.appendUInt16(0)                      // mod time
			output.appendUInt16(0)                      // mod date
			output.appendUInt32(0)                      // crc-32 (unchecked by reader)
			output.appendUInt32(UInt32(payload.count))  // compressed size
			output.appendUInt32(UInt32(entry.data.count)) // uncompressed size
			output.appendUInt16(UInt16(nameBytes.count))
			output.appendUInt16(0)                      // extra length
			output.append(contentsOf: nameBytes)
			output.append(payload)

			// Central directory header
			central.appendUInt32(0x0201_4b50)
			central.appendUInt16(20)                    // version made by
			central.appendUInt16(20)                    // version needed
			central.appendUInt16(0)                     // flags
			central.appendUInt16(entry.method)          // method
			central.appendUInt16(0)                     // mod time
			central.appendUInt16(0)                     // mod date
			central.appendUInt32(0)                     // crc-32
			central.appendUInt32(UInt32(payload.count)) // compressed size
			central.appendUInt32(UInt32(entry.data.count)) // uncompressed size
			central.appendUInt16(UInt16(nameBytes.count))
			central.appendUInt16(0)                     // extra length
			central.appendUInt16(0)                     // comment length
			central.appendUInt16(0)                     // disk number
			central.appendUInt16(0)                     // internal attrs
			central.appendUInt32(0)                     // external attrs
			central.appendUInt32(localOffset)           // local header offset
			central.append(contentsOf: nameBytes)
		}

		let centralOffset = UInt32(output.count)
		output.append(central)

		// End of central directory record
		output.appendUInt32(0x0605_4b50)
		output.appendUInt16(0)                          // disk number
		output.appendUInt16(0)                          // cd start disk
		output.appendUInt16(UInt16(entries.count))      // entries this disk
		output.appendUInt16(UInt16(entries.count))      // total entries
		output.appendUInt32(UInt32(central.count))      // cd size
		output.appendUInt32(centralOffset)              // cd offset
		output.appendUInt16(0)                          // comment length

		return output
	}
}

private extension Data {
	mutating func appendUInt16(_ value: UInt16) {
		append(UInt8(value & 0xFF))
		append(UInt8((value >> 8) & 0xFF))
	}

	mutating func appendUInt32(_ value: UInt32) {
		append(UInt8(value & 0xFF))
		append(UInt8((value >> 8) & 0xFF))
		append(UInt8((value >> 16) & 0xFF))
		append(UInt8((value >> 24) & 0xFF))
	}
}

/// Seeds a context with a fully-featured log book (dives with samples/tanks,
/// sites, gases, trips, buddies, equipment with service history, certifications,
/// owner, and photos with real image bytes) so backup round-trips can verify
/// deep fidelity across every model type.
@MainActor
enum FullLogbook {

	/// The externalIds of the seeded records, for post-restore lookups.
	struct Handles {
		var diveId = ""
		var siteId = ""
		var tripId = ""
		var buddyId = ""
		var equipmentId = ""
		var certificationId = ""
	}

	/// The media bytes seeded into each `@Attribute(.externalStorage)` slot.
	/// Every payload is distinct, so a restore that puts the right bytes in the
	/// wrong slot is still caught. Referenced by the backup round-trip test.
	enum Media {
		static let divePhoto = ImageBytes.jpeg
		static let logbookScan = ImageBytes.png
		static let signature = ImageBytes.gif
		static let equipmentPhoto = ImageBytes.tiffII
		static let buddyPhoto = ImageBytes.tiffMM
		static let certFront = ImageBytes.heic
		static let certBack = ImageBytes.distinctJPEG(marker: 0xB1)
		static let ownerPhoto = ImageBytes.distinctJPEG(marker: 0xC2)
	}

	@discardableResult
	static func seed(into context: ModelContext) throws -> Handles {
		var handles = Handles()

		let site = DiveSite(name: "Palancar Reef", country: "Mexico", region: "Cozumel",
							latitude: 20.3005, longitude: -87.0196, notes: "World-class wall dive")
		context.insert(site)
		handles.siteId = site.externalId

		let gas = GasMix(name: "EAN32", oxygenPercent: 32)
		context.insert(gas)

		let trip = Trip(name: "Cozumel Spring", startDate: .now, endDate: .now,
						location: "Cozumel", address: "Quintana Roo, Mexico",
						urlString: "https://example.com/trip", notes: "Spring trip")
		context.insert(trip)
		handles.tripId = trip.externalId

		let certification = Certification(
			name: "Advanced Open Water", certificationNumber: "AOW-99887",
			dateAchieved: .now, issuingAgency: "PADI",
			instructorName: "Marta Reyes", instructorNumber: "INS-4412",
			diveShop: "Cozumel Divers"
		)
		certification.frontImageData = Media.certFront
		certification.backImageData = Media.certBack
		context.insert(certification)
		handles.certificationId = certification.externalId

		let equipment = Equipment(name: "MK25 EVO", type: .regulator, manufacturer: "Scubapro",
								  model: "MK25", serialNumber: "SN-12345",
								  storeName: "Dive Shop", storeURL: "https://shop.example.com",
								  warranty: "2 years", notes: "Serviced annually",
								  isRetired: false, autoAddToDives: true)
		equipment.photoData = Media.equipmentPhoto
		context.insert(equipment)
		handles.equipmentId = equipment.externalId

		let service = ServiceRecord(serviceDate: .now, servicedBy: "Shop Tech", notes: "Annual service")
		service.equipment = equipment
		context.insert(service)

		let buddy = Buddy(givenName: "Alex", familyName: "Fisher", isRetired: true)
		buddy.photoData = Media.buddyPhoto
		context.insert(buddy)
		handles.buddyId = buddy.externalId

		let owner = try LogbookOwner.fetchOrCreate(in: context)
		owner.givenName = "Jane"
		owner.familyName = "Diver"
		owner.photoData = Media.ownerPhoto
		owner.certifications = [certification]

		let dive = Dive(
			diveNumber: 142, date: .now, title: "Palancar Caves",
			maxDepthMeters: 28.4, durationSeconds: 3120,
			waterTempCelsius: 27.0, airTempCelsius: 30.0, visibilityMeters: 25,
			waterType: .salt, current: .slight, waveConditions: .calm,
			weather: "Sunny", suitType: .wetsuit3mm, weightKg: 4.0,
			diveGuide: "Carlos", diveOperator: "Scuba Club", diveBoat: "Blue Boat",
			rating: 5, notes: "Line one.\n\nLine three.",
			tags: ["reef", "swimthrough"], importSource: "UDDF", site: site, trip: trip
		)
		dive.startLatitude = 20.30
		dive.startLongitude = -87.02
		dive.logbookImageData = Media.logbookScan
		dive.logbookImageFilename = "logbook-page-142.png"
		dive.verificationSignatureData = Media.signature
		context.insert(dive)
		handles.diveId = dive.externalId

		let photo = Photo(imageData: Media.divePhoto, caption: "Swimthrough",
						  sortOrder: 0, originalFilename: "IMG_0142.jpg")
		photo.dive = dive
		context.insert(photo)

		// Associate the equipment with the dive so the dive→equipment
		// relationship is exercised by backup round-trips.
		dive.equipment = [equipment]

		let tank = Tank(gasMix: gas, startPressureBar: 200, endPressureBar: 60)
		tank.dive = dive
		context.insert(tank)

		// A depth sample carrying an optional (decoTTSSeconds) that only survives
		// via the faulting workaround, plus other optionals.
		let sample = DepthSample(elapsedSeconds: 60, depthMeters: 18.5, waterTempCelsius: 20.0,
								 tankPressureBar: 180, ppo2Bar: 0.42, cnsPercent: 3.0,
								 decoTTSSeconds: 90)
		sample.dive = dive
		context.insert(sample)

		try context.save()
		return handles
	}
}
