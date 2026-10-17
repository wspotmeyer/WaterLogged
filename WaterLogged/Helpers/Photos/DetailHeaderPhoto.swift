//
//  DetailHeaderPhoto.swift
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

import SwiftUI

/// A photo that fills whatever frame it's given, under a wash of the system
/// background that's clear across the top and builds toward the bottom edge,
/// easing the photo into the title band. Used as the backdrop of a
/// `DetailHeader`.
struct DetailHeaderPhoto: View {
	let image: CGImage

	/// Opacity of the wash at the photo's bottom edge.
	private static let washOpacity = 0.6
	/// Fraction of the height, from the top, that stays clear before the wash
	/// begins.
	private static let washStart = 0.5

	var body: some View {
		// A clear frame holds the photo, so a fill-scaled image can't push the
		// header wider or taller than its content. User photos can be any
		// shape, so the crop is centred.
		Color.clear
			.overlay {
				Image(decorative: image, scale: 1)
					.resizable()
					.scaledToFill()
			}
			// White in Light Mode and black in Dark Mode, matching the text band
			// and easing the photo toward it.
			.overlay {
				Rectangle()
					.fill(.background)
					.mask {
						LinearGradient(
							stops: [
								.init(color: .clear, location: 0),
								.init(color: .clear, location: Self.washStart),
								.init(color: .black.opacity(Self.washOpacity), location: 1)
							],
							startPoint: .top,
							endPoint: .bottom
						)
					}
			}
			.clipped()
			.accessibilityHidden(true)
	}
}
