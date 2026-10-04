//
//  IndexToggleButton.swift
//  WaterLogged
//
//  Created by John Meyer on 7/28/26.
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

/// A double-chevron button in a liquid-glass bubble that opens and closes a list's jump index
/// column (dive numbers, letters, etc.). It points left (into the list) to reveal the index and right
/// to dismiss it, following the bubble styling of `StatsBarPanel` in HomeMapView.
struct IndexToggleButton: View {
	let isExpanded: Bool
	let action: () -> Void

	/// Rounded on the leading edge, square on the trailing edge so it sits flush against the display.
	private var bubbleShape: some Shape {
		.rect(topLeadingRadius: 5, bottomLeadingRadius: 5, bottomTrailingRadius: 0, topTrailingRadius: 0)
	}

	var body: some View {
		Button(action: action) {
			Label(isExpanded ? "Hide index" : "Show index",
				  systemImage: isExpanded ? "chevron.right.2" : "chevron.left.2")
			.labelStyle(.iconOnly)
			.font(.caption.bold())
			.padding(.vertical, 10)
			.padding(.horizontal, 2)
			.background(.fill.tertiary, in: bubbleShape)
			.foregroundStyle(.white)
			.glassEffect(.clear, in: bubbleShape)
			.opacity(0.4)
			// Enlarge the tap target without changing how the bubble looks: pad outside the
			// styled bubble, then claim the whole padded frame as the hit region. Doing this
			// inside the button label (rather than on the Button) is what actually extends the
			// tappable area; the plain content shape after the fade also keeps a faded glass
			// surface from dropping touches.
			.padding(.leading, 10)
			.contentShape(.rect)
		}
		.buttonStyle(.plain)
	}
}
