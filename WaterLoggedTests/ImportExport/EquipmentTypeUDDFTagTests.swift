//
//  EquipmentTypeUDDFTagTests.swift
//  WaterLoggedTests
//
//  Created by John Meyer on 10/4/26.
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
@testable import WaterLogged

@Suite(.tags(.importExport))
struct EquipmentTypeUDDFTagTests {

	/// The complete UDDF tag → type table, written out explicitly so any change
	/// to how `init?(uddfTag:)` resolves tags shows up here.
	@Test("Every UDDF equipment tag maps to its type", arguments: [
		("boots", EquipmentType.boots),
		("buoyancycontroldevice", .buoyancyControlDevice),
		("camera", .camera),
		("compass", .compass),
		("compressor", .compressor),
		("divecomputer", .diveComputer),
		("fins", .fins),
		("gloves", .gloves),
		("knife", .knife),
		("lead", .lead),
		("light", .light),
		("mask", .mask),
		("rebreather", .rebreather),
		("regulator", .regulator),
		("scooter", .scooter),
		("suit", .suit),
		("variouspieces", .miscellaneous),
		("videocamera", .videoCamera),
		("watch", .watch)
	])
	func mapsTag(tag: String, type: EquipmentType) {
		#expect(EquipmentType(uddfTag: tag) == type)
		#expect(type.uddfTag == tag)
	}

	@Test("Tags that are not equipment pieces map to nothing", arguments: [
		"tank", "equipmentconfiguration", "", "Boots", "unknown"
	])
	func rejectsTag(tag: String) {
		#expect(EquipmentType(uddfTag: tag) == nil)
	}

	@Test func everyTypeExceptTankRoundTrips() {
		for type in EquipmentType.allCases where type != .tank {
			#expect(EquipmentType(uddfTag: type.uddfTag) == type)
		}
	}
}
