//
//  Certification.swift
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

@Model
final class Certification {
	var externalId: String = UUID().uuidString
	var name: String = ""
	var certificationNumber: String = ""
	var dateAchieved: Date?
	var issuingAgency: String = ""
	var instructorName: String = ""
	var instructorNumber: String = ""
	var diveShop: String = ""
	@Attribute(.externalStorage) var frontImageData: Data?
	@Attribute(.externalStorage) var backImageData: Data?

	@Relationship(deleteRule: .nullify, inverse: \Dive.certification)
	var dives: [Dive]? = []

	var totalDiveTimeSeconds: Int {
		dives?.reduce(0) { $0 + $1.durationSeconds } ?? 0
	}

	/// Identifies a certification across an export/import cycle by its content.
	///
	/// UDDF's `certificationType` allows no `id` attribute, so a certification
	/// read back from a file has a fresh `externalId`. A backup's `extras.xml`
	/// uses this key to reattach the fields and card images that UDDF cannot
	/// carry. See `BackupPackager` and `RestorePackager`.
	/// The date is truncated to whole seconds because UDDF datetimes carry no
	/// fractional part, so a key built from the raw interval would stop matching
	/// as soon as the certification made a round trip through a file.
	var backupMatchKey: String {
		let seconds = dateAchieved.map { Int($0.timeIntervalSince1970.rounded(.down)) } ?? 0
		return "\(name)|\(issuingAgency)|\(seconds)"
	}

	var owner: LogbookOwner?

	init(
		externalId: String = UUID().uuidString,
		name: String = "",
		certificationNumber: String = "",
		dateAchieved: Date? = nil,
		issuingAgency: String = "",
		instructorName: String = "",
		instructorNumber: String = "",
		diveShop: String = ""
	) {
		self.externalId = externalId
		self.name = name
		self.certificationNumber = certificationNumber
		self.dateAchieved = dateAchieved
		self.issuingAgency = issuingAgency
		self.instructorName = instructorName
		self.instructorNumber = instructorNumber
		self.diveShop = diveShop
	}
}
