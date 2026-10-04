//
//  DiveNumberBadge.swift
//  WaterLogged
//
//  Created by John Meyer on 8/15/26.
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

/// A dive number in a tinted, bordered box of uniform size, so that the titles beside it line up
/// from row to row.
///
/// The box reserves the width of a four-digit number at the current Dynamic Type size, and longer
/// numbers shrink to fit rather than widening it. Nothing here is a fixed point size, so the badge
/// scales with the reader's preferred text size.
///
/// At accessibility text sizes the badge grows wide enough to crowd out the title beside it, so
/// callers are expected to stack it above the title instead of leading it. In that arrangement
/// there is no neighbor to match heights with, which is why the badge only stretches to fill the
/// available height below the accessibility sizes.
struct DiveNumberBadge: View {
	/// The dive number to display.
	let diveNumber: Int

	/// The text style the number scales with. Pair this with the title it sits next to.
	var textStyle: Font.TextStyle = .title3

	@Environment(\.dynamicTypeSize) private var dynamicTypeSize

	private var font: Font {
		.system(textStyle, design: .rounded, weight: .bold)
	}

	var body: some View {
		// A hidden four-digit template reserves the same width in every badge. Because the digits
		// are monospaced, it matches any four-digit number exactly at any Dynamic Type size, which
		// a hard-coded width could only do for one size.
		Text(verbatim: "0000")
			.font(font)
			.monospacedDigit()
			.hidden()
			.overlay {
				Text(diveNumber, format: .number.grouping(.never))
					.font(font)
					.monospacedDigit()
					.lineLimit(1)
				// Lets five or more digits shrink to fit instead of stretching the box.
					.minimumScaleFactor(0.5)
					.foregroundStyle(.tint)
			}
			.frame(maxHeight: dynamicTypeSize.isAccessibilitySize ? nil : .infinity)
			.padding(.horizontal, 4)
			// An opaque fill rather than a translucent tint wash, so the number keeps at least 3:1
			// contrast (large bold text) whatever gradient or tile the badge sits on. This is a fixed
			// color rather than the `.background` style, because `.background` takes its color from
			// its surroundings, and a macOS sidebar column makes it translucent.
			.background(Color.badgeBackground)
			.clipShape(.rect(cornerRadius: 8))
			// strokeBorder insets the stroke, so the border sits fully inside the rectangle.
			.overlay {
				RoundedRectangle(cornerRadius: 8)
					.strokeBorder(.tint.opacity(0.75), lineWidth: 1)
			}
			.accessibilityElement()
			.accessibilityLabel(Text("Dive \(diveNumber)"))
	}
}

#Preview("Digit counts") {
	VStack(alignment: .leading) {
		ForEach([7, 42, 385, 1024, 10432], id: \.self) { number in
			HStack {
				DiveNumberBadge(diveNumber: number)
				Text("Blue Hole")
					.font(.headline)
			}
		}
	}
	.padding()
}

#Preview("Accessibility size") {
	HStack {
		DiveNumberBadge(diveNumber: 385)
		Text("Blue Hole")
			.font(.headline)
	}
	.padding()
	.dynamicTypeSize(.accessibility3)
}
