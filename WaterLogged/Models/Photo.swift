//
//  Photo.swift
//  WaterLogged
//
//  Created by John Meyer on 4/25/26.
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
final class Photo {
	@Attribute(.externalStorage) var imageData: Data?
	var caption: String = ""
	var sortOrder: Int = 0
	var dateAdded: Date = Date.now
	var originalFilename: String = ""

	// Relationships — each photo belongs to at most one parent
	var dive: Dive?
	var diveSite: DiveSite?
	var trip: Trip?

	init(
		imageData: Data? = nil,
		caption: String = "",
		sortOrder: Int = 0,
		dateAdded: Date = .now,
		originalFilename: String = ""
	) {
		self.imageData = imageData
		self.caption = caption
		self.sortOrder = sortOrder
		self.dateAdded = dateAdded
		self.originalFilename = originalFilename
	}
}
