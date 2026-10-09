//
//  LicenseDocumentTests.swift
//  WaterLoggedTests
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
import Testing
@testable import WaterLogged

struct LicenseDocumentTests {

	/// The GPL and LGPL require their text to ship with the app, so a missing resource is a release blocker.
	@Test(arguments: LicenseDocument.allCases)
	func licenseTextIsBundled(_ license: LicenseDocument) throws {
		let text = try #require(license.text())
		#expect(text.contains("General Public License"))
	}

	@Test func licensesAreTheExpectedVersions() throws {
		#expect(try #require(LicenseDocument.gpl3.text()).contains("Version 3, 29 June 2007"))
		#expect(try #require(LicenseDocument.lgpl21.text()).contains("Version 2.1, February 1999"))
	}
}
