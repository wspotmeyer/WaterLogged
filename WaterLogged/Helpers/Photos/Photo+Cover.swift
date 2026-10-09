//
//  Photo+Cover.swift
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

extension Photo {
	/// The photo shown behind a record's detail-page title: the first one in
	/// the order the user arranged in `PhotoEditSheet`, skipping any without
	/// image data. `nil` when there's nothing to show.
	static func cover(of photos: [Photo]?) -> Photo? {
		(photos ?? [])
			.filter { $0.imageData != nil }
			.min { $0.sortOrder < $1.sortOrder }
	}
}
