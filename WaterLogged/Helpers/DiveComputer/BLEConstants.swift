//
//  BLEConstants.swift
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

import CoreBluetooth

/// GATT identifiers for the dive computers WaterLogged scans for.
///
/// Only the service UUIDs are used in code. The characteristic UUIDs are kept as
/// documentation: the transfer characteristics are found at connect time by their
/// properties (write / notify), so no characteristic UUID is hard-coded.
enum BLEConstants {
	enum Shearwater {
		static let serviceUUID = CBUUID(string: "FE25C237-0ECE-443C-B0AA-E02033E7029D")
		static let characteristicUUID = CBUUID(string: "27B7570B-359E-45A3-91BB-CF7E70049BD2")
	}

	enum Oceanic {
		/// Nordic UART Service (NUS)
		static let serviceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
		/// TX Characteristic (Write — phone to device)
		static let txCharacteristicUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
		/// RX Characteristic (Notify — device to phone)
		static let rxCharacteristicUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
	}

	/// All service UUIDs to scan for when discovering dive computers.
	static let allServiceUUIDs: [CBUUID] = [
		Shearwater.serviceUUID,
		Oceanic.serviceUUID
	]
}
