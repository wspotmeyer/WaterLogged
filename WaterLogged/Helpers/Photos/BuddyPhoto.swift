//
//  BuddyPhoto.swift
//  WaterLogged
//
//  Created by John Meyer on 2/23/26.
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

import SwiftUI

/// A person's photo in a circle, or a placeholder silhouette when there isn't one.
///
/// Hidden from VoiceOver: it always appears beside the person's name, which says everything the
/// photo would.
struct BuddyPhoto: View {
	let photoData: Data?
	var size: CGFloat = 32

	var body: some View {
		Group {
			if let photoData, let image = makeDisplayImage(from: photoData) {
				image
					.resizable()
					.scaledToFill()
					.frame(width: size, height: size)
					.clipShape(.circle)
			} else {
				Image(systemName: "person.circle.fill")
					.resizable()
					.scaledToFit()
					.frame(width: size, height: size)
					.foregroundStyle(.secondary)
			}
		}
		.accessibilityHidden(true)
	}
}
