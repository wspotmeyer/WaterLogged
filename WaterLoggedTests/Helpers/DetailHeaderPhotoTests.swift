//
//  DetailHeaderPhotoTests.swift
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

import CoreGraphics
import Foundation
import ImageIO
import SwiftData
import Testing
import UniformTypeIdentifiers
@testable import WaterLogged

struct DetailHeaderPhotoTests {

	// MARK: - Photo.cover(of:)

	@Test func coverIsTheLowestSortOrderRegardlessOfArrayOrder() throws {
		let container = try TestModelContainer.make()
		let context = container.mainContext
		let photos = [2, 0, 1].map { order in
			let photo = Photo(imageData: Data([UInt8(order)]), caption: "\(order)", sortOrder: order)
			context.insert(photo)
			return photo
		}

		#expect(Photo.cover(of: photos)?.caption == "0")
	}

	@Test func coverSkipsPhotosWithoutImageData() throws {
		let container = try TestModelContainer.make()
		let context = container.mainContext
		let empty = Photo(imageData: nil, caption: "empty", sortOrder: 0)
		let real = Photo(imageData: Data([1]), caption: "real", sortOrder: 1)
		context.insert(empty)
		context.insert(real)

		#expect(Photo.cover(of: [empty, real])?.caption == "real")
	}

	@Test func coverIsNilWithNoPhotos() {
		#expect(Photo.cover(of: nil) == nil)
		#expect(Photo.cover(of: []) == nil)
	}

	// MARK: - HeaderPhotoLoader

	@Test func thumbnailCapsTheLongerSideAndKeepsAspectRatio() throws {
		let data = try #require(Self.pngData(width: 400, height: 200))

		let image = try #require(HeaderPhotoLoader.thumbnail(from: data, maxPixelSize: 100))

		#expect(image.width == 100)
		#expect(image.height == 50)
	}

	@Test func thumbnailIsNilForNonImageData() {
		#expect(HeaderPhotoLoader.thumbnail(from: Data("not an image".utf8), maxPixelSize: 100) == nil)
	}

	/// A solid-color PNG of the given size.
	private static func pngData(width: Int, height: Int) -> Data? {
		guard let context = CGContext(
			data: nil,
			width: width,
			height: height,
			bitsPerComponent: 8,
			bytesPerRow: 0,
			space: CGColorSpaceCreateDeviceRGB(),
			bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
		) else { return nil }
		context.setFillColor(red: 0, green: 0.5, blue: 0.7, alpha: 1)
		context.fill(CGRect(x: 0, y: 0, width: width, height: height))
		guard let image = context.makeImage() else { return nil }

		let data = NSMutableData()
		guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
			return nil
		}
		CGImageDestinationAddImage(destination, image, nil)
		guard CGImageDestinationFinalize(destination) else { return nil }
		return data as Data
	}
}
