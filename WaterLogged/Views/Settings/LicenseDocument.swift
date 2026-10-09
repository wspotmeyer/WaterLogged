//
//  LicenseDocument.swift
//  WaterLogged
//
//  Created by John Meyer on 10/9/26.
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

/// A license whose full text ships in the app bundle (`Resources/Licenses`), so the
/// About screen can show it offline as the GPL and LGPL require.
enum LicenseDocument: String, CaseIterable, Identifiable, Hashable {
	case gpl3 = "GPL-3.0"
	case lgpl21 = "LGPL-2.1"

	var id: String { rawValue }

	/// The license's display name.
	var title: String {
		switch self {
		case .gpl3: String(localized: "GNU General Public License v3")
		case .lgpl21: String(localized: "GNU Lesser General Public License v2.1")
		}
	}

	/// The bundled license text, or `nil` if the resource is missing from the bundle.
	func text(in bundle: Bundle = .main) -> String? {
		guard let url = bundle.url(forResource: rawValue, withExtension: "txt") else { return nil }
		return try? String(contentsOf: url, encoding: .utf8)
	}
}
