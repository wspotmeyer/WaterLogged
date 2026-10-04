//
//  ChartCategoryPalette.swift
//  WaterLogged
//
//  Created by John Meyer on 9/26/26.
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

/// Identity colors for charts that have to tell categories apart by color, such as the slices
/// of a donut. Unlike ``StatMetric/color(for:)`` — one hue per *quantity* — these give one hue
/// per *category*, so they are reserved for charts where every mark is a different category.
///
/// The slots are assigned in this fixed order and never cycled: past ``slotCount`` categories,
/// the rest fold into a neutral "Other" (a `nil` slot). The order is what keeps neighbors apart
/// under color-vision deficiency — every adjacent pair, including the last slot or "Other"
/// wrapping round a ring to meet the first, clears ΔE 8 simulated and 15 unsimulated in both
/// schemes. Aqua and yellow sit under 3:1 on a light surface, so a chart using these colors
/// must also name every category in text.
enum ChartCategoryPalette {
	/// Number of distinct hues before categories fold into "Other".
	static let slotCount = 4

	/// The color for a palette slot, or the neutral "Other" color for a `nil` or
	/// out-of-range slot.
	static func color(slot: Int?, for colorScheme: ColorScheme) -> Color {
		switch (slot, colorScheme) {
		case (0, .dark): Color(.sRGB, red: 0.224, green: 0.529, blue: 0.898)		// #3987E5 blue
		case (0, _): Color(.sRGB, red: 0.165, green: 0.471, blue: 0.839)			// #2A78D6
		case (1, .dark): Color(.sRGB, red: 0.851, green: 0.349, blue: 0.149)		// #D95926 orange
		case (1, _): Color(.sRGB, red: 0.922, green: 0.408, blue: 0.204)			// #EB6834
		case (2, .dark): Color(.sRGB, red: 0.098, green: 0.620, blue: 0.439)		// #199E70 aqua
		case (2, _): Color(.sRGB, red: 0.106, green: 0.686, blue: 0.478)			// #1BAF7A
		case (3, .dark): Color(.sRGB, red: 0.788, green: 0.522, blue: 0)			// #C98500 yellow
		case (3, _): Color(.sRGB, red: 0.929, green: 0.631, blue: 0)				// #EDA100
		// "Other" is darker in dark mode: the lighter gray sits too close to the yellow.
		case (_, .dark): Color(.sRGB, red: 0.431, green: 0.427, blue: 0.408)		// #6E6D68 gray
		case (_, _): Color(.sRGB, red: 0.537, green: 0.529, blue: 0.506)			// #898781
		}
	}
}
