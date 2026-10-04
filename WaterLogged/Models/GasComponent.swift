//
//  GasComponent.swift
//  WaterLogged
//
//  Created by John Meyer on 9/3/26.
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

/// One constituent gas of a `GasMix`, ready for display.
///
/// A plain value type, so it opts out of the module's `MainActor` default and stays usable
/// from importers and other non-isolated code.
nonisolated struct GasComponent: Identifiable, Hashable {
	/// The gases a mix can be made of.
	enum Kind: String, CaseIterable {
		case oxygen
		case nitrogen
		case helium
		case argon
		case hydrogen

		/// Chemical symbol, such as "O₂".
		var symbol: String {
			switch self {
			case .oxygen: "O₂"
			case .nitrogen: "N₂"
			case .helium: "He"
			case .argon: "Ar"
			case .hydrogen: "H₂"
			}
		}

		/// Full gas name, such as "Oxygen".
		var name: String {
			switch self {
			case .oxygen: "Oxygen"
			case .nitrogen: "Nitrogen"
			case .helium: "Helium"
			case .argon: "Argon"
			case .hydrogen: "Hydrogen"
			}
		}
	}

	let kind: Kind

	/// The component's share of the mix as a fraction, such as 0.32 — ready for `.percent` formatting.
	let fraction: Double

	var id: Kind { kind }
	var symbol: String { kind.symbol }
	var name: String { kind.name }

	/// The component as a symbol and percentage, such as "O₂ 32%".
	var summary: String {
		"\(symbol) \(fraction.formatted(.percent.precision(.fractionLength(0))))"
	}
}
