//
//  GasLabelTests.swift
//  WaterLoggedTests
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

import Testing
@testable import WaterLogged

struct GasLabelTests {

	@Test("Labels from percentages", arguments: [
		(o2: 21.0, he: 0.0, label: "Air"),
		(o2: 21.9, he: 0.0, label: "Air"),
		(o2: 32.0, he: 0.0, label: "EAN32"),
		(o2: 36.5, he: 0.0, label: "EAN36"),
		(o2: 100.0, he: 0.0, label: "EAN100"),
		(o2: 21.0, he: 35.0, label: "Trimix 21/35"),
		(o2: 18.0, he: 45.0, label: "Trimix 18/45"),
		(o2: 21.0, he: 0.4, label: "Trimix 21/0")
	])
	func label(o2: Double, he: Double, label: String) {
		#expect(GasLabel.forMix(oxygenPercent: o2, heliumPercent: he) == label)
	}
}
