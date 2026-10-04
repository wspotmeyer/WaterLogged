//
//  TileBackground.swift
//  WaterLogged
//
//  Created by John Meyer on 7/4/26.
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

/// The shared fill used behind cards, tiles, section containers, and list /
/// form rows. It's a single semi-transparent color — a dark blue-gray in dark
/// mode, a light tint in light mode — defined as an adaptive color set in the
/// asset catalog, so it switches between its light and dark variants
/// automatically. Because the color carries built-in translucency, the app
/// background gradient shows softly through every panel, tying the whole UI
/// together.
extension View {
	/// Fills this view's background with the shared tile color, clipped to a
	/// rounded rectangle. Use on plain cards and tiles that draw their own
	/// background (such as `StatCell`).
	func tileBackground(cornerRadius: CGFloat = 12) -> some View {
		background(Color.tileBackground)
			.clipShape(.rect(cornerRadius: cornerRadius))
	}

	/// Applies the shared tile color as this container's background style. Use
	/// on `GroupBox` and other containers that honor `backgroundStyle`,
	/// replacing their default material fill.
	///
	/// macOS needs a second step: its `GroupBox` style ignores
	/// `backgroundStyle` and draws its own faint bordered box, leaving sections
	/// untinted next to the filled tiles around them. There, ``TileGroupBoxStyle``
	/// paints the tile color directly instead. iOS and iPadOS keep Apple's own
	/// `GroupBox` style, which honors `backgroundStyle` as documented.
	func tileBackgroundStyle() -> some View {
		backgroundStyle(Color.tileBackground)
#if os(macOS)
			.groupBoxStyle(.tile)
#endif
	}

	/// Sets the shared translucent tile color as the row background. Apply this
	/// *inside* a `List`/`Form` — on a `Section`, `ForEach`, or row — so the
	/// rows match the app's tiles and section cards instead of showing their
	/// opaque system fill. (`.listRowBackground` has no effect when applied to
	/// the container from the outside.) A row that sets its own
	/// `.listRowBackground` still overrides this default.
	func tileListRowBackground() -> some View {
		listRowBackground(Color.tileBackground)
	}
}

#Preview {
	VStack(spacing: 24) {
		GroupBox("Section") {
			Text("A section container.")
				.frame(maxWidth: .infinity, alignment: .leading)
		}
		.tileBackgroundStyle()

		Text("Tile")
			.padding()
			.frame(width: 120, height: 120)
			.tileBackground()
	}
	.padding()
	.frame(maxWidth: .infinity, maxHeight: .infinity)
	.appGradient()
}
