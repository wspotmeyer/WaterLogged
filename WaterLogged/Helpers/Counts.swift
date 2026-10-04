//
//  Counts.swift
//  WaterLogged
//
//  Created by John Meyer on 4/25/26.
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

/// A capsule showing a number of dives. Colors come from ``StatMetric`` so a count here matches
/// the same quantity plotted in the statistics bar charts.
struct DiveCount: View {
	let count: Int
	let font: Font
	@Environment(\.colorScheme) private var colorScheme

	var body: some View {
		CountCapsule(text: "\(count)", color: StatMetric.dives.color(for: colorScheme), font: font)
	}
}

/// A capsule showing a number of trips.
struct TripCount: View {
	let count: Int
	let font: Font
	@Environment(\.colorScheme) private var colorScheme

	var body: some View {
		CountCapsule(text: "\(count)", color: StatMetric.trips.color(for: colorScheme), font: font)
	}
}

/// A capsule showing an amount of bottom time, and so colored to match the Bottom Time metric
/// rather than the dive or trip counts it usually sits beside.
struct TimeCount: View {
	let seconds: Int
	let font: Font
	@Environment(\.colorScheme) private var colorScheme

	private var formatted: String {
		let hours = seconds / 3600
		let minutes = (seconds % 3600) / 60
		let secs = seconds % 60
		if hours > 0 {
			return "\(hours)h \(minutes)m"
		} else if minutes > 0 {
			return "\(minutes)m \(secs)s"
		} else {
			return "\(secs)s"
		}
	}

	var body: some View {
		CountCapsule(text: formatted, color: StatMetric.bottomTime.color(for: colorScheme), font: font)
	}
}

/// A count drawn in its metric color over a 15% wash of that color.
///
/// The wash is translucent, so on its own the app gradient and tiles show through it and pull
/// the text below WCAG's 4.5:1. Each scheme compensates differently, keeping the metric's hue:
/// dark mode lays the wash over an opaque black base (not the system background — macOS's dark
/// window background is gray and still fails); light mode deepens the text 30% toward black.
struct CountCapsule: View {
	let text: String
	let color: Color
	let font: Font

	@Environment(\.colorScheme) private var colorScheme

	private var ink: Color {
		colorScheme == .dark ? color : color.mix(with: .black, by: 0.3, in: .device)
	}

	var body: some View {
		Text(text)
			.font(font.bold())
			.fontDesign(.rounded)
			.monospacedDigit()
			.padding(.horizontal, 12)
			.padding(.vertical, 2)
			.background(color.opacity(0.15))
			.background(colorScheme == .dark ? Color.black : Color.clear)
			.foregroundStyle(ink)
			.clipShape(Capsule())
			// strokeBorder insets the stroke, so the border sits fully inside the capsule.
			.overlay {
				Capsule()
					.strokeBorder(color.opacity(0.25), lineWidth: 1)
			}

	}
}

#Preview("TimeCount") {
	TimeCount(seconds: 23000, font: .title)
}

#Preview("DiveCount") {
	DiveCount(count: 42, font: .title)
}

#Preview("TripCount") {
	TripCount(count: 7, font: .title)
}

// All three together, which is how they appear in a detail header.
#Preview("Together") {
	HStack {
		TimeCount(seconds: 23000, font: .headline)
		DiveCount(count: 42, font: .headline)
		TripCount(count: 7, font: .headline)
	}
	.padding()
}
