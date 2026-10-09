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

/// A photo that fills whatever frame it's given and fades to transparent
/// toward its bottom edge, blending into the app gradient behind it. Used as
/// the backdrop of a `DetailHeader`.
struct DetailHeaderPhoto: View {
	let image: CGImage

	/// Fraction of the height that stays fully opaque before the fade begins.
	private static let fadeStart = 0.45
	/// Opacity of the black wash over the photo in Dark Mode, so white titles
	/// stay readable.
	private static let darkModeDimming = 0.35

	@Environment(\.colorScheme) private var colorScheme

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
			.overlay {
				if colorScheme == .dark {
					Color.black.opacity(Self.darkModeDimming)
				}
			}
			.clipped()
			.mask {
				LinearGradient(
					stops: [
						.init(color: .black, location: 0),
						.init(color: .black, location: Self.fadeStart),
						.init(color: .clear, location: 1)
					],
					startPoint: .top,
					endPoint: .bottom
				)
			}
			.accessibilityHidden(true)
	}
}
