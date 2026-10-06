//
//  Trip.swift
//  WaterLogged
//
//  Created by John Meyer on 4/20/26.
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
final class Trip {
	var externalId: String = UUID().uuidString
	var name: String = ""
	var startDate: Date = Date.now
	var endDate: Date = Date.now
	var location: String = ""
	var address: String = ""
	var latitude: Double?
	var longitude: Double?
	var urlString: String = ""
	var notes: String = ""

	@Relationship(deleteRule: .nullify, inverse: \Dive.trip)
	var dives: [Dive]? = []

	@Relationship(deleteRule: .cascade, inverse: \Photo.trip)
	var photos: [Photo]? = []

	/// The trip's URL, if a valid URL string is stored.
	var url: URL? {
		guard !urlString.isEmpty else { return nil }
		return URL(string: urlString)
	}

	/// A formatted date range string for display.
	var dateRangeFormatted: String {
		let calendar = Calendar.current
		let sameYear = calendar.component(.year, from: startDate) == calendar.component(.year, from: endDate)
		let end = endDate.formatted(date: .abbreviated, time: .omitted)

		if startDate == endDate {
			return end
		}

		let start: String
		if sameYear {
			start = startDate.formatted(.dateTime.month(.abbreviated).day())
		} else {
			start = startDate.formatted(date: .abbreviated, time: .omitted)
		}

		return "\(start) – \(end)"
	}

	/// The number of dives associated with this trip.
	var diveCount: Int {
		dives?.count ?? 0
	}

	init(
		externalId: String = UUID().uuidString,
		name: String = "",
		startDate: Date = .now,
		endDate: Date = .now,
		location: String = "",
		address: String = "",
		latitude: Double? = nil,
		longitude: Double? = nil,
		urlString: String = "",
		notes: String = ""
	) {
		self.externalId = externalId
		self.name = name
		self.startDate = startDate
		self.endDate = endDate
		self.location = location
		self.address = address
		self.latitude = latitude
		self.longitude = longitude
		self.urlString = urlString
		self.notes = notes
	}
}
