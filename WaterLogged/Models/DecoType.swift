//
//  DecoType.swift
//  WaterLogged
//
//  Created by John Meyer on 8/21/26.
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

/// The decompression state a dive computer reported for a single profile sample.
///
/// Every import source spells this concept differently — libdivecomputer produces
/// `"Deco Stop"`, UDDF's `<decostop kind="…">` produces `"mandatory"` — which meant
/// consumers had to string-match each vendor's vocabulary and quietly mishandled the
/// spellings they didn't know about. Importers now normalize to a case of this enum,
/// and `DepthSample.decoStatus` parses values written by older builds, so this is the
/// only place a deco spelling has to be understood.
nonisolated enum DecoType: String, Codable, CaseIterable, Sendable {
	/// Within the no-decompression limit: no stop is required.
	case noDecoLimit = "ndl"
	/// A precautionary stop that the diver may skip.
	case safetyStop = "safety"
	/// A mandatory decompression stop.
	case decoStop = "deco"
	/// A stop taken well above the mandatory ceiling to slow off-gassing.
	case deepStop = "deep"

	/// Parses a value produced by an import source or stored by an earlier build.
	///
	/// Returns `nil` for anything unrecognized — including libdivecomputer's
	/// `"Unknown"` — which callers treat as "this sample carries no deco information"
	/// rather than inventing a state the computer never reported.
	init?(importedValue: String) {
		// Reduce spelling differences to one form: "Deco Stop", "decostop" and
		// "DECO_STOP" all normalize to "decostop".
		switch importedValue.lowercased().filter(\.isLetter) {
			case "ndl", "nodeco", "nodecolimit", "nodecotime":
				self = .noDecoLimit
			case "safety", "safetystop":
				self = .safetyStop
			case "deco", "decostop", "mandatory", "mandatorystop",
				 "decompression", "decompressionstop":
				self = .decoStop
			case "deep", "deepstop":
				self = .deepStop
			default:
				return nil
		}
	}

	/// The name shown to the diver.
	var displayName: LocalizedStringResource {
		switch self {
			case .noDecoLimit: "No Deco"
			case .safetyStop: "Safety Stop"
			case .decoStop: "Deco Stop"
			case .deepStop: "Deep Stop"
		}
	}

	/// Whether the sample represents a stop the diver was holding, as opposed to
	/// simply reporting remaining no-decompression time.
	var isStop: Bool { self != .noDecoLimit }

	/// The `kind` attribute for a UDDF `<decostop>` element, whose vocabulary the
	/// schema limits to `safety` and `mandatory`.
	///
	/// `nil` for `.noDecoLimit`, which UDDF expresses as `<nodecotime>` rather than
	/// as a stop. A deep stop has no UDDF equivalent and is written as `mandatory`,
	/// since it is a stop the computer asked for.
	var uddfDecoStopKind: String? {
		switch self {
			case .noDecoLimit: nil
			case .safetyStop: "safety"
			case .decoStop, .deepStop: "mandatory"
		}
	}
}
