//
//  ImageFileHelperTests.swift
//  WaterLoggedTests
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

@Suite(.tags(.backup))
struct ImageFileHelperTests {

	@Test("File extension detected from magic bytes", arguments: [
		(bytes: ImageBytes.jpeg, ext: "jpg"),
		(bytes: ImageBytes.png, ext: "png"),
		(bytes: ImageBytes.gif, ext: "gif"),
		(bytes: ImageBytes.tiffII, ext: "tiff"),
		(bytes: ImageBytes.tiffMM, ext: "tiff"),
		(bytes: ImageBytes.heic, ext: "heic"),
		(bytes: ImageBytes.unknown, ext: "jpg"),
		(bytes: ImageBytes.tooShort, ext: "jpg")
	])
	func fileExtension(bytes: Data, ext: String) {
		#expect(ImageFileHelper.fileExtension(for: bytes) == ext)
	}

	@Test func defaultFilenameUsesDetectedExtension() {
		#expect(ImageFileHelper.defaultFilename(for: ImageBytes.png) == "Photo.png")
		#expect(ImageFileHelper.defaultFilename(for: ImageBytes.jpeg) == "Photo.jpg")
	}
}
