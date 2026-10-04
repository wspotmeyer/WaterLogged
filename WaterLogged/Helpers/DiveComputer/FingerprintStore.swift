//
//  FingerprintStore.swift
//  WaterLogged
//
//  Created by John Meyer on 2/23/26.
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

/// The last dive downloaded from one physical dive computer, as libdivecomputer
/// identifies it.
struct DeviceFingerprint: Codable, Sendable {
	/// The opaque blob from the dive callback, handed straight back to
	/// `dc_device_set_fingerprint` on the next download.
	var fingerprint: Data
	/// Recorded for diagnostics only — the store is keyed by peripheral, not serial.
	var serial: UInt32?
	var productName: String
	var savedAt: Date
}

/// Remembers the newest dive already downloaded from each dive computer, so the
/// next download can stop as soon as the device reaches it.
///
/// This is purely a **transfer optimization**. libdivecomputer compares the blob
/// against the device's own log and aborts the transfer at the first match — for
/// Oceanic, `oceanic_common_device_logbook` breaks out of its backwards walk and
/// then only streams profile bytes for the dives that survived, instead of every
/// dive the device still holds. Skipping it costs time, never correctness:
/// whether a downloaded dive is actually new is decided against the logbook by
/// `ImportedDiveMatcher`, so a stale, missing, or mismatched fingerprint just
/// means a longer download.
///
/// Records are keyed by the BLE peripheral's identifier rather than the model
/// name. The serial from `DC_EVENT_DEVINFO` would be ideal, but Oceanic emits it
/// *inside* `dc_device_foreach` — after the point where the fingerprint has to be
/// set — while the peripheral identifier is known before connecting and is unique
/// per physical device. The older per-model last-import-date files this store used
/// to write are obsolete and simply ignored.
enum FingerprintStore {

	/// The stored fingerprint for a device, or nil if it has never been downloaded.
	static func fingerprint(forDeviceKey key: String) -> DeviceFingerprint? {
		guard let data = try? Data(contentsOf: fileURL(forDeviceKey: key)) else {
			return nil
		}
		return try? JSONDecoder().decode(DeviceFingerprint.self, from: data)
	}

	/// Records the newest downloaded dive for a device.
	static func save(_ record: DeviceFingerprint, forDeviceKey key: String) {
		let url = fileURL(forDeviceKey: key)

		try? FileManager.default.createDirectory(
			at: url.deletingLastPathComponent(),
			withIntermediateDirectories: true
		)
		guard let data = try? JSONEncoder().encode(record) else { return }
		try? data.write(to: url)
	}

	/// Forgets a device, so its next download reads the whole log again.
	static func remove(forDeviceKey key: String) {
		try? FileManager.default.removeItem(at: fileURL(forDeviceKey: key))
	}

	// MARK: - Private

	private static func fileURL(forDeviceKey key: String) -> URL {
		let sanitized = key.replacing("/", with: "_")
			.replacing(":", with: "_")
		return URL.applicationSupportDirectory
			.appending(path: "DiveFingerprints")
			.appending(path: "\(sanitized).json")
	}
}
