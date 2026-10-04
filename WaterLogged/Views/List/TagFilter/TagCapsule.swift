//
//  TagCapsule.swift
//  WaterLogged
//
//  Created by John Meyer on 8/16/26.
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

/// The magenta capsule a tag is drawn in, shared by the read-only tag rows (`TagsListView`) and the
/// tappable chips in the dive list's tag filter (`TagFilterChip`) so the two can't drift apart.
private struct TagCapsuleModifier: ViewModifier {

	/// Filled when selected, tinted-and-outlined when not.
	let isSelected: Bool
	@Environment(\.colorScheme) private var colorScheme

	/// Orange. Deep in light mode and bright in dark mode: an unselected capsule draws this color as
	/// `.caption.bold()` text over a 15% wash of itself, and at roughly 12pt that counts as
	/// normal-size text, so it needs 4.5:1 rather than 3:1 — no single step clears that against both
	/// a pale and a dark surface. Plain `.orange` manages only 1.82:1 that way in light mode, hence
	/// the deeper step here; dark mode can afford the system orange itself.
	///
	/// A tag capsule can appear beside the bottom-time capsule in a dive's detail view. Since bottom
	/// time moved from amber to green in ``StatMetric`` the two are far apart for normal vision
	/// (ΔE2000 ~48–57); under simulated protanopia/deuteranopia they come within ~7–10. Both
	/// capsules are read from their text, so nothing here is identified by color alone.
	private var tagColor: Color {
		colorScheme == .dark
			? Color(.sRGB, red: 1, green: 0.624, blue: 0.039)		// #FF9F0A
			: Color(.sRGB, red: 0.604, green: 0.204, blue: 0.071)	// #9A3412
	}

	/// Ink on a selected, solid-filled capsule. White clears 4.5:1 on the deep light-mode fill, but
	/// reaches only ~2.9:1 on any dark-mode fill bright enough to serve the unselected state, so
	/// dark mode inks the selected capsule instead of lightening it. The ink echoes the dark tile
	/// color, which reads as the label being punched out of the chip.
	private var selectedInk: Color {
		colorScheme == .dark
			? Color(.sRGB, red: 0.118, green: 0.165, blue: 0.200)	// #1E2A33
			: .white
	}

	func body(content: Content) -> some View {
		content
			.font(.caption.bold())
			.padding(.horizontal, 10)
			.padding(.vertical, 4)
			.background(isSelected ? tagColor : tagColor.opacity(0.15))
			.foregroundStyle(isSelected ? selectedInk : tagColor)
			.clipShape(.capsule)
			// strokeBorder insets the stroke, so the border sits fully inside the capsule.
			.overlay {
				Capsule()
					.strokeBorder(tagColor.opacity(isSelected ? 1 : 0.5), lineWidth: 1)
			}
	}
}

extension View {
	/// Draws this label as a tag capsule. See `TagCapsuleModifier`.
	func tagCapsule(isSelected: Bool = false) -> some View {
		modifier(TagCapsuleModifier(isSelected: isSelected))
	}
}

// Both states over the tile fill they actually sit on, since the unselected capsule's wash is
// translucent and its contrast depends on what shows through.
#Preview {
	VStack(spacing: 12) {
		HStack(spacing: 8) {
			Text("wreck").tagCapsule()
			Text("night").tagCapsule()
			Text("drift").tagCapsule()
		}
		HStack(spacing: 8) {
			Text("wreck").tagCapsule(isSelected: true)
			Text("night").tagCapsule(isSelected: true)
		}
	}
	.padding()
	.tileBackground()
	.padding()
}
