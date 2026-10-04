//
//  Tank.swift
//  WaterLogged
//
//  Created by John Meyer on 6/5/26.
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

/// A tank used during a dive. A dive can have multiple tanks (e.g. sidemount,
/// stage tanks, deco tanks) — each one carries its own gas mix and pressures.
@Model
final class Tank {
	var externalId: String? = UUID().uuidString
	var equipment: Equipment?
	var gasMix: GasMix?
	var startPressureBar: Double?
	var endPressureBar: Double?

	var dive: Dive?

	init(
		externalId: String? = UUID().uuidString,
		equipment: Equipment? = nil,
		gasMix: GasMix? = nil,
		startPressureBar: Double? = nil,
		endPressureBar: Double? = nil
	) {
		self.externalId = externalId
		self.equipment = equipment
		self.gasMix = gasMix
		self.startPressureBar = startPressureBar
		self.endPressureBar = endPressureBar
	}
}
