//
//  PhotoReplaceTests.swift
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
import SwiftData
@testable import WaterLogged

@Suite(.tags(.backup))
struct PhotoReplaceTests {

	@Test func replacesExistingPhotosInEntryOrder() throws {
		let container = try TestModelContainer.make()
		let context = container.mainContext
		let dive = Dive()
		context.insert(dive)
		for index in 0..<3 {
			let photo = Photo(imageData: Data([UInt8(index)]), caption: "old \(index)", sortOrder: index, originalFilename: "")
			photo.dive = dive
			context.insert(photo)
		}
		try context.save()

		let entries = [
			PhotoEntry(imageData: Data([9]), caption: "second"),
			PhotoEntry(imageData: Data([8]), caption: "first")
		]
		Photo.replace(dive.photos, with: entries, in: context) { $0.dive = dive }

		let photos = try context.fetch(FetchDescriptor<Photo>(sortBy: [SortDescriptor(\.sortOrder)]))
		#expect(photos.map(\.caption) == ["second", "first"])
		#expect(photos.map(\.sortOrder) == [0, 1])
		#expect(photos.allSatisfy { $0.dive?.persistentModelID == dive.persistentModelID })
	}
}
