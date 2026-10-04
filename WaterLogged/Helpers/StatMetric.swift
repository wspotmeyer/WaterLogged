//
//  StatMetric.swift
//  WaterLogged
//
//  Created by John Meyer on 9/24/26.
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

/// One of the three quantities the app totals up about a group of dives.
///
/// Lives here rather than beside the charts because it owns the shared color palette: it is the
/// metric picker in ``MetricBarChartSection``, and it colors the count capsules in `Counts.swift`,
/// so a quantity looks the same wherever it is shown.
enum StatMetric: CaseIterable, Identifiable {
	case dives
	case bottomTime
	case trips

	var id: Self { self }

	var pickerTitle: LocalizedStringKey {
		switch self {
		case .dives: "Dives"
		case .bottomTime: "Bottom Time"
		case .trips: "Trips"
		}
	}

	/// Name of the metric as it appears in the section title and as the chart's value label.
	var name: String {
		switch self {
		case .dives: "Dives"
		case .bottomTime: "Bottom Time"
		case .trips: "Trips"
		}
	}

	/// Whether the metric counts things, and so should never be plotted on a fractional axis.
	var isCount: Bool {
		switch self {
		case .dives, .trips: true
		case .bottomTime: false
		}
	}

	/// The color for this metric, resolved for the current color scheme. Used both for the bars
	/// in ``MetricBarChartSection`` and for the count capsules in `Counts.swift`, so the same
	/// quantity wears the same color wherever it shows up.
	///
	/// In the charts these colors carry no identity load — a section draws one metric at a time,
	/// and the section title, the segmented picker, and the value label on every bar all name it.
	///
	/// Each scheme gets its own step rather than one value used for both, so all three stay
	/// inside the scheme's lightness band, above the chroma floor where a hue starts reading as
	/// gray, and at or above 3:1 as a bar against the tile fill. As capsule text each clears 4.5:1
	/// once ``CountCapsule`` applies its per-scheme treatment (black base in dark mode, a deeper
	/// ink in light mode).
	///
	/// Bottom time is Apple's system green. It stays clear of the trips teal (ΔE2000 ≥ 17, and no
	/// closer under simulated protanopia or deuteranopia, since the two differ mainly in blue,
	/// which both preserve) and far from the dives blue.
	func color(for colorScheme: ColorScheme) -> Color {
		switch (self, colorScheme) {
		case (.dives, .dark): Color(.sRGB, red: 0.231, green: 0.510, blue: 0.965)		// #3B82F6
		case (.dives, _): Color(.sRGB, red: 0.102, green: 0.451, blue: 0.910)			// #1A73E8
		case (.bottomTime, .dark): Color(.sRGB, red: 0.188, green: 0.820, blue: 0.345)	// #30D158
		case (.bottomTime, _): Color(.sRGB, red: 0.141, green: 0.541, blue: 0.239)		// #248A3D
		case (.trips, .dark): Color(.sRGB, red: 0.184, green: 0.659, blue: 0.580)		// #2FA894
		case (.trips, _): Color(.sRGB, red: 0, green: 0.537, blue: 0.482)				// #00897B
		}
	}
}

// Every metric's color at bar size and at capsule size, in both schemes.
#Preview("Palette") {
	VStack(alignment: .leading, spacing: 12) {
		ForEach(StatMetric.allCases) { metric in
			HStack(spacing: 12) {
				Text(metric.name)
					.frame(width: 110, alignment: .leading)
				Capsule()
					.fill(metric.color(for: .light))
					.frame(width: 160, height: 11)
				CountCapsule(text: metric.name, color: metric.color(for: .light), font: .headline)
			}
		}
	}
	.padding()
}
