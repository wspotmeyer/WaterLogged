//
//  DiveComputerDescriptor.swift
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

@preconcurrency import CoreBluetooth

/// Identifies the vendor/brand of a dive computer.
/// The raw value is used for display in the UI.
enum DiveComputerBrand: String, Sendable {
	case shearwater = "Shearwater"
	case oceanic = "Oceanic"
	case suunto = "Suunto"
	case mares = "Mares"
	case scubapro = "Scubapro"
	case cressi = "Cressi"
	case heinrichsWeikamp = "Heinrichs Weikamp"
	case garmin = "Garmin"
	case atomics = "Atomic Aquatics"
	case generic = "Dive Computer"

	/// Map a libdivecomputer vendor string to a brand.
	static func from(vendorName: String) -> DiveComputerBrand {
		let lowered = vendorName.lowercased()
		if lowered.localizedStandardContains("shearwater") { return .shearwater }
		if lowered.localizedStandardContains("oceanic") { return .oceanic }
		if lowered.localizedStandardContains("suunto") { return .suunto }
		if lowered.localizedStandardContains("mares") { return .mares }
		if lowered.localizedStandardContains("uwatec") || lowered.localizedStandardContains("scubapro") { return .scubapro }
		if lowered.localizedStandardContains("cressi") { return .cressi }
		if lowered.localizedStandardContains("heinrichs") { return .heinrichsWeikamp }
		if lowered.localizedStandardContains("garmin") { return .garmin }
		if lowered.localizedStandardContains("atomic") { return .atomics }
		return .generic
	}
}

/// The transport type used to communicate with a dive computer.
enum DeviceTransport: @unchecked Sendable {
	/// Bluetooth Low Energy via CoreBluetooth.
	case ble(CBPeripheral)
}

/// Information about a discovered dive computer.
struct DiscoveredDevice: Identifiable, @unchecked Sendable {
	let id: UUID
	let name: String
	let brand: DiveComputerBrand
	let rssi: Int
	let transport: DeviceTransport
}

/// Result of identifying a BLE peripheral as a dive computer.
struct DeviceIdentification {
	let brand: DiveComputerBrand
}

/// Identifies a known dive computer brand from a peripheral's advertised data.
/// Uses libdivecomputer's descriptor database for comprehensive matching
/// across hundreds of dive computer models.
enum DeviceIdentifier {
	/// Attempt to identify the brand of a discovered BLE peripheral.
	///
	/// First tries libdivecomputer's descriptor matching (which covers all
	/// supported BLE dive computers), then falls back to the Shearwater
	/// service UUID and known name patterns for edge cases.
	static func identify(
		name: String?,
		advertisedServiceUUIDs: [CBUUID]?
	) -> DeviceIdentification? {
		guard let name else { return nil }

		// Primary: use libdivecomputer's descriptor database for matching.
		// Only accept the result if we can map the vendor to a known brand;
		// unrecognised vendors resolve to .generic, which likely indicates a
		// false-positive prefix match against an unrelated BLE peripheral.
		if let descriptor = LibDCDeviceHandler.findDescriptor(
			deviceName: name
		) {
			let vendor = LibDCDeviceHandler.vendorName(for: descriptor)
			dc_descriptor_free(descriptor)
			let brand = DiveComputerBrand.from(vendorName: vendor)
			if brand != .generic {
				return DeviceIdentification(brand: brand)
			}
		}

		// Fallback: match by Shearwater's proprietary service UUID.
		// Note: We intentionally do NOT match on the Oceanic/NUS UUID
		// (6E400001-...) because it is the generic Nordic UART Service
		// used by many non-dive-computer BLE devices.
		let services = advertisedServiceUUIDs ?? []
		if services.contains(BLEConstants.Shearwater.serviceUUID) {
			return DeviceIdentification(brand: .shearwater)
		}

		// Fallback: match by known name patterns for devices that
		// might not be in libdivecomputer's BLE filter database yet.
		// These patterns are intentionally specific to avoid matching
		// unrelated BLE peripherals.
		if shearwaterNamePatterns.contains(where: { name.hasPrefix($0) }) {
			return DeviceIdentification(brand: .shearwater)
		}
		if oceanicNamePatterns.contains(where: { name.hasPrefix($0) }) {
			return DeviceIdentification(brand: .oceanic)
		}

		return nil
	}

	private static let shearwaterNamePatterns = [
		"Perdix", "Teric", "Peregrine", "Petrel", "NERD", "Tern"
	]

	private static let oceanicNamePatterns = [
		"Oceanic ", "Pro Plus ", "OCI ", "OCi ",
		"Geo 4.0", "Veo 4.0", "VTX",
		"Aeris ", "Sherwood ", "Hollis ", "Tusa ",
	]
}
