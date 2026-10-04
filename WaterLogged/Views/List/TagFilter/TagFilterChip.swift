//
//  TagFilterChip.swift
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

/// One tag in the dive list's filter strip: a capsule that toggles whether dives must carry the tag.
struct TagFilterChip: View {
	let tag: String
	let isSelected: Bool
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			Text(tag)
				.tagCapsule(isSelected: isSelected)
		}
		.buttonStyle(.plain)
		.accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
	}
}

#Preview {
	@Previewable @State var selected: Set<String> = ["wreck"]

	HStack {
		ForEach(["drift", "reef", "wreck"], id: \.self) { tag in
			TagFilterChip(tag: tag, isSelected: selected.contains(tag)) {
				if selected.contains(tag) {
					selected.remove(tag)
				} else {
					selected.insert(tag)
				}
			}
		}
	}
	.padding()
}
