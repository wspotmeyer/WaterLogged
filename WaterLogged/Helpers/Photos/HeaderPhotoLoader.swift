//
//  HeaderPhotoLoader.swift
//  WaterLogged
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

/// Decodes a downsized copy of a stored photo for a detail-page header.
///
/// Photos are stored at full camera resolution, so decoding one as-is for a
/// banner would waste memory and stall the main thread. `nonisolated` so it can
/// run from a detached task.
nonisolated enum HeaderPhotoLoader {
	/// Returns the image scaled so its longer side is at most `maxPixelSize`,
	/// with any EXIF orientation applied, or `nil` if `data` isn't an image.
	static func thumbnail(from data: Data, maxPixelSize: Int) -> CGImage? {
		guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
		let options: [CFString: Any] = [
			kCGImageSourceCreateThumbnailFromImageAlways: true,
			kCGImageSourceCreateThumbnailWithTransform: true,
			kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
			kCGImageSourceShouldCacheImmediately: true
		]
		return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
	}
}
