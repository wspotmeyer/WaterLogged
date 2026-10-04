//
//  TagsListView.swift
//  WaterLogged
//
//  Created by John Meyer on 2/23/26.
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

/// Displays a row of tag capsules preceded by a tag symbol.
///
/// Tags are shown in localized alphabetical order regardless of the order they were entered, matching
/// the order of the tag filter strip.
struct TagsListView: View {
	let tags: [String]

	init(tags: [String]) {
		self.tags = tags.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
	}

	var body: some View {
		HStack(alignment: .top, spacing: 8) {
			Image(systemName: "tag")
				.font(.caption)
				.foregroundStyle(.secondary)
				.padding(.vertical, 4)
			ForEach(tags, id: \.self) { tag in
				Text(tag)
					.tagCapsule()
			}
		}
	}
}

#Preview {
	TagsListView(tags: ["wreck", "night", "drift"])
}
