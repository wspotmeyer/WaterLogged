//
//  DisclosureToggleButton.swift
//  WaterLogged
//
//  Created by John Meyer on 10/4/26.
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

/// The small chevron button that expands or collapses a detail-view section.
/// The chevron is the only thing drawn; `subject` (e.g. "Dives") gives
/// VoiceOver a spoken label such as "Show Dives" or "Hide Dives".
struct DisclosureToggleButton: View {
	@Binding var isExpanded: Bool
	let subject: String

	var body: some View {
		Button {
			withAnimation(.smooth) {
				isExpanded.toggle()
			}
		} label: {
			Label(
				isExpanded ? "Hide \(subject)" : "Show \(subject)",
				systemImage: isExpanded ? "chevron.down" : "chevron.right"
			)
			.labelStyle(.iconOnly)
			.imageScale(.small)
			// The generous frame enlarges the tap target; pinning the chevron to
			// its trailing edge keeps it flush with the row chevrons below.
			.frame(width: 32, height: 32, alignment: .trailing)
			.contentShape(.rect)
		}
		.buttonStyle(.plain)
		.font(.subheadline)
	}
}

#Preview {
	@Previewable @State var collapsed = false
	@Previewable @State var expanded = true
	VStack(alignment: .leading) {
		HStack {
			Text("Dives").font(.title2.bold())
			Spacer()
			DisclosureToggleButton(isExpanded: $collapsed, subject: "Dives")
		}
		HStack {
			Text("Trips").font(.title2.bold())
			Spacer()
			DisclosureToggleButton(isExpanded: $expanded, subject: "Trips")
		}
	}
	.padding()
}
