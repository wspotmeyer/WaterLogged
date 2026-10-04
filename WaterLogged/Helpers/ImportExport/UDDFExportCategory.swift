//
//  UDDFExportCategory.swift
//  WaterLogged
//
//  Created by John Meyer on 8/15/26.
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

/// One independently selectable slice of the logbook in a UDDF export.
///
/// Categories are self-contained: excluding one only drops that data and any
/// cross-references to it, so a partial export always remains valid UDDF.
nonisolated enum UDDFExportCategory: String, CaseIterable, Identifiable, Sendable {
	case dives
	case diveSites
	case gasMixes
	case buddies
	case equipment
	case certifications
	case trips
	case diverProfile

	var id: Self { self }

	var title: LocalizedStringResource {
		switch self {
			case .dives: "Dives"
			case .diveSites: "Dive Sites"
			case .gasMixes: "Gas Mixes"
			case .buddies: "Buddies"
			case .equipment: "Equipment"
			case .certifications: "Certifications"
			case .trips: "Trips"
			case .diverProfile: "Diver Profile"
		}
	}

	var systemImage: String {
		switch self {
			case .dives: "water.waves.and.arrow.trianglehead.down"
			case .diveSites: "mappin.and.ellipse"
			case .gasMixes: "aqi.medium"
			case .buddies: "person.2"
			case .equipment: "briefcase"
			case .certifications: "graduationcap"
			case .trips: "airplane.path.dotted"
			case .diverProfile: "person.text.rectangle"
		}
	}
}

/// The categories to include in a UDDF export.
typealias UDDFExportSelection = Set<UDDFExportCategory>

nonisolated extension UDDFExportSelection {
	/// Every category — the default for a full-logbook export.
	static var all: UDDFExportSelection { UDDFExportSelection(UDDFExportCategory.allCases) }

	/// A file name (without extension) describing the selection: a single
	/// category names itself, anything broader is just the logbook.
	var suggestedFileName: String {
		if count == 1, let only = first {
			"WaterLogged \(String(localized: only.title))"
		} else {
			"WaterLogged Logbook"
		}
	}
}

/// How many items exist in each category, used to show the user what an export
/// will contain and to decide whether there is anything to export at all.
nonisolated struct UDDFExportCounts: Sendable, Hashable {
	var dives = 0
	var diveSites = 0
	var gasMixes = 0
	var buddies = 0
	var equipment = 0
	var certifications = 0
	var trips = 0
	var diverProfile = 0

	subscript(category: UDDFExportCategory) -> Int {
		switch category {
			case .dives: dives
			case .diveSites: diveSites
			case .gasMixes: gasMixes
			case .buddies: buddies
			case .equipment: equipment
			case .certifications: certifications
			case .trips: trips
			case .diverProfile: diverProfile
		}
	}

	/// The total number of items the given selection would export.
	func total(for selection: UDDFExportSelection) -> Int {
		selection.reduce(0) { $0 + self[$1] }
	}

	/// Whether at least one selected category has something in it.
	func hasContent(for selection: UDDFExportSelection) -> Bool {
		total(for: selection) > 0
	}
}
