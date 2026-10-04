//
//  DiveSite.swift
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
import SwiftData

@Model
final class DiveSite {
	var externalId: String = UUID().uuidString
	var name: String = ""
	var country: String = ""
	var region: String = ""
	var latitude: Double?
	var longitude: Double?
	var notes: String = ""

	@Relationship(deleteRule: .nullify, inverse: \Dive.site)
	var dives: [Dive]? = []

	@Relationship(deleteRule: .cascade, inverse: \Photo.diveSite)
	var photos: [Photo]? = []

	var totalDiveTimeSeconds: Int {
		dives?.reduce(0) { $0 + $1.durationSeconds } ?? 0
	}

	init(
		externalId: String = UUID().uuidString,
		name: String = "",
		country: String = "",
		region: String = "",
		latitude: Double? = nil,
		longitude: Double? = nil,
		notes: String = ""
	) {
		self.externalId = externalId
		self.name = name
		self.country = country
		self.region = region
		self.latitude = latitude
		self.longitude = longitude
		self.notes = notes
	}
}
