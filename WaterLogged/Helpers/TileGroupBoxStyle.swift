//
//  TileGroupBoxStyle.swift
//  WaterLogged
//
//  Created by John Meyer on 9/13/26.
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

/// Draws a `GroupBox` as one of the app's tiles: the label stacked above the
/// content, both inside a rounded rectangle filled with the shared tile color.
///
/// This exists for macOS. The built-in `GroupBox` style there ignores
/// `backgroundStyle()` and draws its own faint bordered box instead, so
/// sections such as `DetailSection` came out untinted while the plain tiles
/// around them (`StatCell` and friends, which call `tileBackground()`) were
/// filled. Painting the fill directly sidesteps the container style entirely,
/// so the sections match both the tiles above them and their iOS counterparts.
///
/// The metrics mirror `StatCell`: default padding and the shared 12-point
/// corner radius.
struct TileGroupBoxStyle: GroupBoxStyle {
	func makeBody(configuration: Configuration) -> some View {
		VStack(alignment: .leading, spacing: 4) {
			configuration.label
			configuration.content
		}
		.padding()
		.frame(maxWidth: .infinity, alignment: .leading)
		.tileBackground()
	}
}

extension GroupBoxStyle where Self == TileGroupBoxStyle {
	/// A `GroupBox` drawn as one of the app's tiles. See ``TileGroupBoxStyle``.
	static var tile: TileGroupBoxStyle { TileGroupBoxStyle() }
}
