//
//  BuildInfoTests.swift
//  WaterLoggedTests
//
//  Created by John Meyer on 10/10/26.
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

struct BuildInfoTests {

	@Test func readsTheHashWrittenByTheScript() {
		#expect(BuildInfo.commit(fromFileContents: "d3fa839\n") == "d3fa839")
	}

	@Test func acceptsAFullLengthHashAndNormalizesCase() {
		let full = "D3FA839E60F68B0123456789ABCDEF0123456789"
		#expect(BuildInfo.commit(fromFileContents: full) == full.lowercased())
	}

	@Test(arguments: ["", "   \n", "abc12", "not-a-hash", "d3fa83g", String(repeating: "a", count: 41)])
	func rejectsContentsThatAreNotAHash(_ contents: String) {
		#expect(BuildInfo.commit(fromFileContents: contents) == nil)
	}

	@Test func buildLineShowsTheCommitAfterTheBuildNumber() {
		#expect(BuildInfo.buildDescription(buildNumber: "42", commit: "d3fa839") == "(42) d3fa839")
	}

	@Test func buildLineFallsBackToTheBuildNumberAlone() {
		#expect(BuildInfo.buildDescription(buildNumber: "42", commit: nil) == "42")
	}
}
