//
//  ISO8601DateParserTests.swift
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
import Foundation
@testable import WaterLogged

struct ISO8601DateParserTests {

	private func local(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0, _ s: Int = 0) -> Date? {
		DateComponents(calendar: .current, timeZone: .current, year: y, month: mo, day: d, hour: h, minute: mi, second: s).date
	}

	@Test func explicitTimeZoneIsRespected() {
		#expect(ISO8601DateParser.date(from: "2006-04-28T08:15:00Z") == Date(timeIntervalSince1970: 1_146_212_100))
		#expect(ISO8601DateParser.date(from: "2006-04-28T10:15:00+02:00") == Date(timeIntervalSince1970: 1_146_212_100))
	}

	@Test("Zone-less forms are read as local time", arguments: [
		"2006-04-28T08:15:00", "2006-04-28T08:15"
	])
	func zonelessIsLocal(_ string: String) {
		#expect(ISO8601DateParser.date(from: string) == local(2006, 4, 28, 8, 15))
	}

	@Test func dateOnlyIsLocalMidnight() {
		#expect(ISO8601DateParser.date(from: "2006-04-28") == local(2006, 4, 28))
	}

	@Test("Unparseable input yields nil", arguments: ["", "yesterday", "28/04/2006"])
	func garbage(_ string: String) {
		#expect(ISO8601DateParser.date(from: string) == nil)
	}
}
