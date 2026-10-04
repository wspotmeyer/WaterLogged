//
//  GasLabel.swift
//  WaterLogged
//
//  Created by John Meyer on 10/4/26.
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

/// The default name given to a gas mix created by an import: "Air", "EAN32",
/// or "Trimix 21/35".
///
/// `nonisolated` because the dive computer download parses gases off the main actor.
nonisolated enum GasLabel {
	/// Builds the label from percentages (32 for 32 %). Fractions of a percent
	/// are truncated in the label, but any helium above zero makes it trimix.
	static func forMix(oxygenPercent o2: Double, heliumPercent he: Double) -> String {
		if he > 0 {
			"Trimix \(Int(o2))/\(Int(he))"
		} else if Int(o2) == 21 {
			"Air"
		} else {
			"EAN\(Int(o2))"
		}
	}
}
