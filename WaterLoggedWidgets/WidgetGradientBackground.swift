//
//  WidgetGradientBackground.swift
//  WaterLoggedWidgets
//
//  Created by John Meyer on 6/29/26.
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

/// The widget's background gradient: a dark navy gradient used in both light
/// and dark system appearances. Its colors are set here, not read from the
/// app's color assets, so it no longer matches the app's turquoise dark
/// gradient exactly. Pair with a forced dark color scheme so semantic text
/// styles stay legible.
struct WidgetGradientBackground: View {
	var body: some View {
		LinearGradient(
			colors: [
				Color(red: 0x16 / 255, green: 0x34 / 255, blue: 0x4E / 255),
				Color(red: 0x0B / 255, green: 0x1A / 255, blue: 0x2B / 255)
			],
			startPoint: .top,
			endPoint: .bottom
		)
	}
}
