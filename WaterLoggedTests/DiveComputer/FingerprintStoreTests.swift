//
//  FingerprintStoreTests.swift
//  WaterLoggedTests
//
//  Created by John Meyer on 9/13/26.
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

/// Round-tripping the opaque per-device fingerprint through its on-disk store.
///
/// The blob is handed back to `dc_device_set_fingerprint` byte for byte, and that
/// call rejects a wrong-sized blob outright, so exact preservation matters.
@Suite(.tags(.diveComputerDuplicates))
struct FingerprintStoreTests {

	/// A unique key per test so these never collide with each other or with a
	/// real device's record.
	private func scratchKey() -> String {
		"WLTest-\(UUID().uuidString)"
	}

	@Test("An unknown device has no fingerprint")
	func unknownDeviceIsEmpty() {
		#expect(FingerprintStore.fingerprint(forDeviceKey: scratchKey()) == nil)
	}

	@Test("A saved fingerprint round-trips byte for byte")
	func roundTripsExactly() {
		let key = scratchKey()
		defer { FingerprintStore.remove(forDeviceKey: key) }

		// 16 bytes, the size of an Oceanic logbook entry, including a zero and a
		// high byte so any text mangling would show up.
		let blob = Data([0x00, 0xFF, 0x10, 0x7F, 0x80, 0x01, 0x02, 0x03,
						 0xAB, 0xCD, 0xEF, 0x00, 0x12, 0x34, 0x56, 0x78])

		FingerprintStore.save(
			DeviceFingerprint(
				fingerprint: blob,
				serial: 123_456,
				productName: "Pro Plus X",
				savedAt: .now
			),
			forDeviceKey: key
		)

		let loaded = FingerprintStore.fingerprint(forDeviceKey: key)
		#expect(loaded?.fingerprint == blob)
		#expect(loaded?.fingerprint.count == 16)
		#expect(loaded?.serial == 123_456)
		#expect(loaded?.productName == "Pro Plus X")
	}

	@Test("Saving again replaces the previous fingerprint")
	func saveOverwrites() {
		let key = scratchKey()
		defer { FingerprintStore.remove(forDeviceKey: key) }

		let first = Data(repeating: 0x11, count: 16)
		let second = Data(repeating: 0x22, count: 16)

		for blob in [first, second] {
			FingerprintStore.save(
				DeviceFingerprint(
					fingerprint: blob, serial: nil,
					productName: "Pro Plus X", savedAt: .now
				),
				forDeviceKey: key
			)
		}

		#expect(FingerprintStore.fingerprint(forDeviceKey: key)?.fingerprint == second)
	}

	@Test("Removing a device forces a full read next time")
	func removeClearsTheRecord() {
		let key = scratchKey()
		FingerprintStore.save(
			DeviceFingerprint(
				fingerprint: Data(repeating: 0x33, count: 8), serial: nil,
				productName: "Veo 4.0", savedAt: .now
			),
			forDeviceKey: key
		)
		#expect(FingerprintStore.fingerprint(forDeviceKey: key) != nil)

		FingerprintStore.remove(forDeviceKey: key)
		#expect(FingerprintStore.fingerprint(forDeviceKey: key) == nil)
	}

	@Test("Two devices keep separate fingerprints")
	func keysAreIndependent() {
		let keyA = scratchKey()
		let keyB = scratchKey()
		defer {
			FingerprintStore.remove(forDeviceKey: keyA)
			FingerprintStore.remove(forDeviceKey: keyB)
		}

		let blobA = Data(repeating: 0xAA, count: 16)
		let blobB = Data(repeating: 0xBB, count: 16)
		FingerprintStore.save(
			DeviceFingerprint(fingerprint: blobA, serial: 1, productName: "Pro Plus X", savedAt: .now),
			forDeviceKey: keyA
		)
		FingerprintStore.save(
			DeviceFingerprint(fingerprint: blobB, serial: 2, productName: "Pro Plus X", savedAt: .now),
			forDeviceKey: keyB
		)

		#expect(FingerprintStore.fingerprint(forDeviceKey: keyA)?.fingerprint == blobA)
		#expect(FingerprintStore.fingerprint(forDeviceKey: keyB)?.fingerprint == blobB)
	}

	@Test("A key containing path separators is still usable")
	func keyIsSanitized() {
		let key = "\(scratchKey())/with:separators"
		defer { FingerprintStore.remove(forDeviceKey: key) }

		let blob = Data(repeating: 0x44, count: 16)
		FingerprintStore.save(
			DeviceFingerprint(fingerprint: blob, serial: nil, productName: "X", savedAt: .now),
			forDeviceKey: key
		)

		#expect(FingerprintStore.fingerprint(forDeviceKey: key)?.fingerprint == blob)
	}
}
