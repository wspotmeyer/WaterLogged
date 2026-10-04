//
//  UDDFIdentifier.swift
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

/// Converts between a model's `externalId` and the XML `id` written to a UDDF file.
///
/// UDDF declares `id` as `xs:ID` and `ref` as `xs:IDREF`, so both must be XML
/// NCNames: they cannot begin with a digit, which a raw UUID does about 62% of
/// the time. Prefixing makes every id a valid NCName, and the transform is
/// reversible so an exported file re-imports with its original identifiers.
nonisolated enum UDDFIdentifier {
	/// Marks ids that WaterLogged generated, so `externalId(from:)` knows to
	/// remove it. Files from other apps keep whatever ids they came with.
	static let prefix = "wl-"

	/// The XML `id` to write for a model's `externalId`.
	static func xmlID(for externalId: String) -> String {
		externalId.isEmpty ? prefix : prefix + externalId
	}

	/// A derived id for a child element that needs its own `xs:ID` but has no
	/// model of its own, such as the `<manufacturer>` inside an equipment piece.
	static func xmlID(for externalId: String, suffix: String) -> String {
		xmlID(for: externalId) + "-" + suffix
	}

	/// The `externalId` to store for an `id`/`ref` read from a file, undoing
	/// `xmlID(for:)` when the id came from WaterLogged.
	static func externalId(from xmlID: String) -> String {
		guard xmlID.hasPrefix(prefix) else { return xmlID }
		return String(xmlID.dropFirst(prefix.count))
	}
}
