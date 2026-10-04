//
//  ParsedDiveFixtures.swift
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

import Foundation
@testable import WaterLogged

extension ParsedDiveData {
	/// A 40-minute, 18 m dive as a dive computer would report it, for tests that
	/// only care about a few fields.
	static func fixture(
		dateTime: Date = .now,
		samples: [ParsedSampleData] = [],
		gasMixes: [ParsedGasMixData] = [],
		computerModel: String = "Oceanic Test"
	) -> ParsedDiveData {
		ParsedDiveData(
			dateTime: dateTime,
			durationSeconds: 2_400,
			maxDepthMeters: 18,
			avgDepthMeters: 12,
			waterTempCelsius: 24,
			samples: samples,
			gasMixes: gasMixes,
			diveNumber: nil,
			computerModel: computerModel,
			serialNumber: nil
		)
	}
}
