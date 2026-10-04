//
//  Photo+Replace.swift
//  WaterLogged
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

import SwiftData

extension Photo {
	/// Replaces an owner's photos with the edited list from `PhotoEditSheet`.
	///
	/// Deletes every photo in `existing`, then inserts one new `Photo` per entry
	/// with `sortOrder` matching its position. `attach` links each new photo to its
	/// owner (e.g. `{ $0.dive = dive }`). Saves the context when done.
	static func replace(
		_ existing: [Photo]?,
		with entries: [PhotoEntry],
		in context: ModelContext,
		attach: (Photo) -> Void
	) {
		for photo in existing ?? [] {
			context.delete(photo)
		}
		for (index, entry) in entries.enumerated() {
			let photo = Photo(imageData: entry.imageData, caption: entry.caption, sortOrder: index, originalFilename: entry.originalFilename)
			attach(photo)
			context.insert(photo)
		}
		try? context.save()
	}
}
