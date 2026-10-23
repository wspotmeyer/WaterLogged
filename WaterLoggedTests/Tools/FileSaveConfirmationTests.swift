//
//  FileSaveConfirmationTests.swift
//  WaterLoggedTests
//
//  Created by John Meyer on 10/23/26.
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

struct FileSaveConfirmationTests {

	@Test func namesTheFileAndFolder() {
		let message = FileSaveConfirmation.message(fileName: "WaterLogged_2026-10-23.zip", folderName: "Backups")
		#expect(message == "Saved “WaterLogged_2026-10-23.zip” to Backups.")
	}

	@Test(arguments: [nil, "", "  ", "/"] as [String?])
	func omitsAnUnknownFolder(_ folderName: String?) {
		let message = FileSaveConfirmation.message(fileName: "WaterLogged.zip", folderName: folderName)
		#expect(message == "Saved “WaterLogged.zip”.")
	}

	@Test func readsTheFileAndFolderFromTheDestinationURL() {
		let url = URL(filePath: "/nonexistent-WaterLogged-test/Backups/WaterLogged.zip")
		let message = FileSaveConfirmation.message(for: url)
		#expect(message == "Saved “WaterLogged.zip” to Backups.")
	}

	@Test func handlesAFileAtTheRoot() {
		let message = FileSaveConfirmation.message(for: URL(filePath: "/WaterLogged.zip"))
		#expect(message.contains("WaterLogged.zip"))
	}
}
