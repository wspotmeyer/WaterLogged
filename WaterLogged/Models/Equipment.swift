//
//  Equipment.swift
//  WaterLogged
//
//  Created by John Meyer on 3/28/26.
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

enum EquipmentType: String, Codable, CaseIterable, Identifiable {
	case boots
	case buoyancyControlDevice
	case camera
	case compass
	case compressor
	case diveComputer
	case fins
	case gloves
	case knife
	case lead
	case light
	case mask
	case rebreather
	case regulator
	case scooter
	case suit
	case tank
	case miscellaneous
	case videoCamera
	case watch

	var id: Self { self }

	var label: String {
		switch self {
			case .boots: "Boots"
			case .buoyancyControlDevice: "BCD"
			case .camera: "Camera"
			case .compass: "Compass"
			case .compressor: "Compressor"
			case .diveComputer: "Dive Computer"
			case .fins: "Fins"
			case .gloves: "Gloves"
			case .knife: "Knife"
			case .lead: "Lead / Weights"
			case .light: "Light"
			case .mask: "Mask"
			case .rebreather: "Rebreather"
			case .regulator: "Regulator"
			case .scooter: "Scooter / DPV"
			case .suit: "Suit"
			case .tank: "Tank"
			case .miscellaneous: "Miscellaneous"
			case .videoCamera: "Video Camera"
			case .watch: "Watch"
		}
	}

	/// The icon for this type, which may be an SF Symbol or custom artwork from the asset
	/// catalog. Render it with `EquipmentTypeIcon` or `EquipmentTypeLabel`.
	///
	/// To move a case onto custom artwork, add the SVG to the `Icons` group in
	/// `Assets.xcassets` (template rendering, preserve vector data), then change that
	/// case here to `.custom(...)`.
	var icon: EquipmentIcon {
		switch self {
			case .boots: .custom(.booties)
			case .buoyancyControlDevice: .custom(.bcd)
			case .camera: .custom(.underwaterCamera)
			case .compass: .custom(.compass)
			case .compressor: .custom(.compressor)
			case .diveComputer: .custom(.diveComputer)
			case .fins: .custom(.fins)
			case .gloves: .custom(.glove)
			case .knife: .custom(.knife)
			case .lead: .custom(.weights)
			case .light: .custom(.diveLight)
			case .mask: .custom(.diveMask)
			case .rebreather: .custom(.rebreather)
			case .regulator: .custom(.regulator)
			case .scooter: .custom(.scooter)
			case .suit: .custom(.wetSuit)
			case .tank: .custom(.tank)
			// No custom artwork for the catch-all category; an SF Symbol reads better here.
			case .miscellaneous: .system("ellipsis.circle")
			case .videoCamera: .custom(.videoCamera)
			case .watch: .custom(.diveWatch)
		}
	}

	/// The UDDF XML tag name for this equipment type.
	var uddfTag: String {
		switch self {
			case .boots: "boots"
			case .buoyancyControlDevice: "buoyancycontroldevice"
			case .camera: "camera"
			case .compass: "compass"
			case .compressor: "compressor"
			case .diveComputer: "divecomputer"
			case .fins: "fins"
			case .gloves: "gloves"
			case .knife: "knife"
			case .lead: "lead"
			case .light: "light"
			case .mask: "mask"
			case .rebreather: "rebreather"
			case .regulator: "regulator"
			case .scooter: "scooter"
			case .suit: "suit"
			case .tank: "tank"
			case .miscellaneous: "variouspieces"
			case .videoCamera: "videocamera"
			case .watch: "watch"
		}
	}

	/// Maps a UDDF equipment XML tag name to an `EquipmentType`. `tank` is
	/// deliberately absent: UDDF tanks are imported as `Tank` records, not equipment.
	init?(uddfTag: String) {
		switch uddfTag {
			case "boots": self = .boots
			case "buoyancycontroldevice": self = .buoyancyControlDevice
			case "camera": self = .camera
			case "compass": self = .compass
			case "compressor": self = .compressor
			case "divecomputer": self = .diveComputer
			case "fins": self = .fins
			case "gloves": self = .gloves
			case "knife": self = .knife
			case "lead": self = .lead
			case "light": self = .light
			case "mask": self = .mask
			case "rebreather": self = .rebreather
			case "regulator": self = .regulator
			case "scooter": self = .scooter
			case "suit": self = .suit
			case "variouspieces": self = .miscellaneous
			case "videocamera": self = .videoCamera
			case "watch": self = .watch
			default: return nil
		}
	}
}

@Model
final class Equipment {
	var externalId: String = UUID().uuidString
	var name: String = ""
	var type: EquipmentType?
	var manufacturer: String = ""
	var model: String = ""
	var serialNumber: String = ""
	var purchaseDate: Date?
	var purchasePrice: Double?
	var storeName: String = ""
	var storeURL: String = ""
	var warranty: String = ""
	var notes: String = ""
	@Attribute(.externalStorage) var photoData: Data?
	var isRetired: Bool = false
	var autoAddToDives: Bool = false

	@Relationship(deleteRule: .cascade, inverse: \ServiceRecord.equipment)
	var serviceHistory: [ServiceRecord]? = []

	var dives: [Dive]? = []

	/// Tanks that reference this item as their cylinder. Exists so `Tank.equipment`
	/// has an inverse, which CloudKit sync requires of every relationship.
	/// Deleting the equipment clears the link without deleting the tank.
	@Relationship(deleteRule: .nullify, inverse: \Tank.equipment)
	var tanks: [Tank]? = []

	var totalDiveTimeSeconds: Int {
		dives?.reduce(0) { $0 + $1.durationSeconds } ?? 0
	}

	/// Resolves the equipment type, falling back to `.miscellaneous` for pre-existing records.
	var resolvedType: EquipmentType {
		type ?? .miscellaneous
	}

	init(
		externalId: String = UUID().uuidString,
		name: String = "",
		type: EquipmentType = .miscellaneous,
		manufacturer: String = "",
		model: String = "",
		serialNumber: String = "",
		purchaseDate: Date? = nil,
		purchasePrice: Double? = nil,
		storeName: String = "",
		storeURL: String = "",
		warranty: String = "",
		notes: String = "",
		photoData: Data? = nil,
		isRetired: Bool = false,
		autoAddToDives: Bool = false
	) {
		self.externalId = externalId
		self.name = name
		self.type = type
		self.manufacturer = manufacturer
		self.model = model
		self.serialNumber = serialNumber
		self.purchaseDate = purchaseDate
		self.purchasePrice = purchasePrice
		self.storeName = storeName
		self.storeURL = storeURL
		self.warranty = warranty
		self.notes = notes
		self.photoData = photoData
		self.isRetired = isRetired
		self.autoAddToDives = autoAddToDives
	}
}
