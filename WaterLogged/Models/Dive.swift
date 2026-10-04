//
//  Dive.swift
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
final class Dive {

	// MARK: - Identity
	var externalId: String = UUID().uuidString
	var diveNumber: Int = 0
	var date: Date = Date.now
	var title: String = ""

	// MARK: - Depth & Time
	var maxDepthMeters: Double = 0
	var surfaceIntervalSeconds: Int?
	var durationSeconds: Int = 0  // bottom time

	// Computed helpers
	var displayTitle: String {
		if !title.isEmpty {
			return title
		} else if let siteName = site?.name, !siteName.isEmpty {
			return siteName
		} else {
			return "Dive #\(diveNumber)"
		}
	}

	/// Returns the stored surface interval if set, otherwise computes it from
	/// the previous dive's end time. Returns 0 if no previous dive is found
	/// or the gap exceeds 24 hours.
	var effectiveSurfaceIntervalSeconds: Int {
		if let stored = surfaceIntervalSeconds {
			return stored
		}
		guard let context = modelContext else { return 0 }
		let currentDate = date
		let predicate = #Predicate<Dive> { $0.date < currentDate }
		var descriptor = FetchDescriptor<Dive>(
			predicate: predicate,
			sortBy: [SortDescriptor(\Dive.date, order: .reverse)]
		)
		descriptor.fetchLimit = 1
		guard let previousDive = (try? context.fetch(descriptor))?.first else { return 0 }
		let previousEndDate = previousDive.date.addingTimeInterval(Double(previousDive.durationSeconds))
		let gap = Int(currentDate.timeIntervalSince(previousEndDate))
		let twentyFourHours = 24 * 3600
		return gap > 0 && gap < twentyFourHours ? gap : 0
	}

	var surfaceIntervalFormatted: String {
		let total = effectiveSurfaceIntervalSeconds
		let days = total / 86400
		let hours = (total % 86400) / 3600
		let minutes = (total % 3600) / 60
		if days > 0 {
			return "\(days)d \(hours)h \(minutes)m"
		} else if hours > 0 {
			return "\(hours)h \(minutes)m"
		} else {
			return "\(minutes)m"
		}
	}

	var durationFormatted: String {
		let hours = durationSeconds / 3600
		let minutes = (durationSeconds % 3600) / 60
		let seconds = durationSeconds % 60
		if hours > 0 {
			return "\(hours)h \(minutes)m \(seconds)s"
		} else if minutes > 0 {
			return "\(minutes)m \(seconds)s"
		} else {
			return "\(seconds)s"
		}
	}

	/// The dive's end date and time, computed from `date` plus `durationSeconds`.
	var endDate: Date {
		date.addingTimeInterval(TimeInterval(durationSeconds))
	}

	/// Sum of bottom times for all dives on or before this dive's date, including this one.
	var cumulativeDiveTimeSeconds: Int {
		guard let context = modelContext else { return durationSeconds }
		let currentDate = date
		let predicate = #Predicate<Dive> { $0.date <= currentDate }
		let descriptor = FetchDescriptor<Dive>(predicate: predicate)
		let dives = (try? context.fetch(descriptor)) ?? []
		return dives.reduce(0) { $0 + $1.durationSeconds }
	}

	var cumulativeDiveTimeFormatted: String {
		let total = cumulativeDiveTimeSeconds
		let hours = total / 3600
		let minutes = (total % 3600) / 60
		let seconds = total % 60
		if hours > 0 {
			return "\(hours)h \(minutes)m \(seconds)s"
		} else if minutes > 0 {
			return "\(minutes)m \(seconds)s"
		} else {
			return "\(seconds)s"
		}
	}

	// MARK: - Conditions
	var waterTempCelsius: Double?
	var airTempCelsius: Double?
	var visibilityMeters: Double?
	var waterType: WaterType?
	var current: Current?
	var waveConditions: WaveConditions?
	var weather: String = ""

	// MARK: - Protection
	var suitType: SuitType?
	var weightKg: Double?

	// MARK: - People
	var diveGuide: String?
	var diveOperator: String?
	var diveBoat: String?

	// MARK: - Ratings & Notes
	var rating: Int = 0          // 1–5 stars
	var notes: String = ""
	var tags: [String] = []

	// MARK: - Logbook
	@Attribute(.externalStorage) var logbookImageData: Data?
	var logbookImageFilename: String = ""
	@Attribute(.externalStorage) var verificationSignatureData: Data?

	// MARK: - Geolocation
	var startLatitude: Double?
	var startLongitude: Double?
	var endLatitude: Double?
	var endLongitude: Double?

	// MARK: - Source
	var importSource: String = "Manual"  // e.g. "Manual", "Suunto", "Garmin"

	// MARK: - Relationships
	var site: DiveSite?
	var trip: Trip?
	var certification: Certification?

	@Relationship(deleteRule: .cascade)
	var diveProfile: [DepthSample]? = []

	@Relationship(deleteRule: .cascade, inverse: \Tank.dive)
	var tanks: [Tank]? = []

	@Relationship(inverse: \Equipment.dives)
	var equipment: [Equipment]? = []

	@Relationship(inverse: \Buddy.dives)
	var buddies: [Buddy]? = []

	@Relationship(deleteRule: .cascade, inverse: \Photo.dive)
	var photos: [Photo]? = []

	// MARK: - Init
	init(
		externalId: String = UUID().uuidString,
		diveNumber: Int = 0,
		date: Date = .now,
		title: String = "",
		maxDepthMeters: Double = 0,
		durationSeconds: Int = 0,
		waterTempCelsius: Double? = nil,
		airTempCelsius: Double? = nil,
		visibilityMeters: Double? = nil,
		waterType: WaterType? = nil,
		current: Current? = nil,
		waveConditions: WaveConditions? = nil,
		weather: String = "",
		suitType: SuitType? = nil,
		weightKg: Double? = nil,
		diveGuide: String? = nil,
		diveOperator: String? = nil,
		diveBoat: String? = nil,
		rating: Int = 0,
		notes: String = "",
		tags: [String] = [],
		startLatitude: Double? = nil,
		startLongitude: Double? = nil,
		endLatitude: Double? = nil,
		endLongitude: Double? = nil,
		importSource: String = "Manual",
		site: DiveSite? = nil,
		trip: Trip? = nil
	) {
		self.externalId = externalId
		self.diveNumber = diveNumber
		self.date = date
		self.title = title
		self.maxDepthMeters = maxDepthMeters
		self.durationSeconds = durationSeconds
		self.waterTempCelsius = waterTempCelsius
		self.airTempCelsius = airTempCelsius
		self.visibilityMeters = visibilityMeters
		self.waterType = waterType
		self.current = current
		self.waveConditions = waveConditions
		self.weather = weather
		self.suitType = suitType
		self.weightKg = weightKg
		self.diveGuide = diveGuide
		self.diveOperator = diveOperator
		self.diveBoat = diveBoat
		self.rating = rating
		self.notes = notes
		self.tags = tags
		self.startLatitude = startLatitude
		self.startLongitude = startLongitude
		self.endLatitude = endLatitude
		self.endLongitude = endLongitude
		self.importSource = importSource
		self.site = site
		self.trip = trip
	}
}

// MARK: - Enums

enum WaterType: String, Codable, CaseIterable {
	case salt = "Salt"
	case fresh = "Fresh"
	case brackish = "Brackish"
}

enum Current: String, Codable, CaseIterable {
	case none = "None"
	case slight = "Slight"
	case moderate = "Moderate"
	case strong = "Strong"
	case extreme = "Extreme"
}

enum WaveConditions: String, Codable, CaseIterable {
	case calm = "Calm"
	case slight = "Slight"
	case moderate = "Moderate"
	case rough = "Rough"
}

enum SuitType: String, Codable, CaseIterable {
	case swimsuit = "Swimsuit"
	case rashguard = "Rashguard"
	case diveskin = "Diveskin"
	case wetsuithalfmm = "Wetsuit 0.5mm"
	case wetsuit3mm = "Wetsuit 3mm"
	case wetsuit5mm = "Wetsuit 5mm"
	case wetsuit7mm = "Wetsuit 7mm"
	case semidry = "Semi-Dry"
	case drysuit = "Drysuit"
}
