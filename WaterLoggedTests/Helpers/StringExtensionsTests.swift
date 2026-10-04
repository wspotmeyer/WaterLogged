//
//  StringExtensionsTests.swift
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

struct StringExtensionsTests {

	@Test("Comma-separated tags are trimmed and empty entries dropped", arguments: [
		(input: "wreck, night,, deep ", expected: ["wreck", "night", "deep"]),
		(input: "", expected: []),
		(input: " , ,", expected: []),
		(input: "single", expected: ["single"])
	])
	func commaSeparatedTags(input: String, expected: [String]) {
		#expect(input.commaSeparatedTags == expected)
	}

	@Test func markdownStrippedRemovesFormattingCharacters() {
		#expect("**Blue** _Hole_ [link](x)".markdownStripped == "Blue Hole linkx")
	}
}
