//
//  UDDFOmittedDataGroup.swift
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

/// WaterLogged data that the UDDF format has no representation for, grouped by
/// the kind of record it belongs to, so the export tool can tell the user what
/// a UDDF file leaves behind.
///
/// This mirrors what `BackupPackager` writes to `extras.xml` and `media/` in a
/// backup archive: if a field moves in or out of the extras file, update the
/// matching case here.
nonisolated enum UDDFOmittedDataGroup: String, CaseIterable, Identifiable, Sendable {
	case dives
	case gasMixes
	case photos
	case equipment
	case buddies
	case certifications
	case diveSites
	case trips
	case diverProfile

	var id: Self { self }

	var title: LocalizedStringResource {
		switch self {
			case .dives: "Dives"
			case .gasMixes: "Gas Mixes"
			case .photos: "Photos"
			case .equipment: "Equipment"
			case .buddies: "Buddies"
			case .certifications: "Certifications"
			case .diveSites: "Dive Sites"
			case .trips: "Trips"
			case .diverProfile: "Diver Profile"
		}
	}

	/// The specific fields left out for this group, written for the user.
	var details: LocalizedStringResource {
		switch self {
				// Equipment used and weight carried ARE exported, as <equipmentused> and
				// <leadquantity> — don't list them here.
			case .dives:
			"""
			Titles, dive guide, operator, boat, weather, water type, current, wave conditions, suit type, \
			entry and exit coordinates, tags, which certification a dive is linked to, log book page scans, \
			verification signatures, and time-to-surface readings in depth profiles.
			"""
				// The mixes are exported; only the per-dive link can be lost, because UDDF
				// requires a starting pressure on every <tankdata>. See UDDFExporter.writeTankData.
			case .gasMixes:
			"""
			The mixes themselves are exported. A tank is only written when it has a starting \
			pressure, so on a dive with no recorded tank pressures the link between that dive and \
			its gas mix is left out.
			"""
			case .photos:
			"""
			Every photo attached to a dive, site, or trip, along with its caption, ordering, and \
			original file name.
			"""
			case .equipment:
			"""
			Store name and web link, warranty, notes, retired status, whether the item is added to new \
			dives automatically, photos, and the full service history.
			"""
			case .buddies:
				"Photos and retired status."
			case .certifications:
				"Certification number, dive shop, instructor number, and front and back card images."
			case .diveSites:
				"Site notes."
			case .trips:
				"Street address and web link."
			case .diverProfile:
				"Your profile photo."
		}
	}
}
