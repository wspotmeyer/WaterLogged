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

struct BuddyPhoto: View {
	let photoData: Data?
	var size: CGFloat = 32

	var body: some View {
		if let photoData, let image = makeImage(from: photoData) {
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

	private func makeImage(from data: Data) -> Image? {
#if canImport(UIKit)
		guard let uiImage = UIImage(data: data) else { return nil }
		return Image(uiImage: uiImage)
#elseif canImport(AppKit)
		guard let nsImage = NSImage(data: data) else { return nil }
		return Image(nsImage: nsImage)
#endif
	}
}
