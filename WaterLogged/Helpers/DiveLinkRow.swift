//
//  DiveLinkRow.swift
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

/// One row in a detail view's expandable "Dives" list: the dive's title and
/// date, linking to its `DiveDetailView`.
struct DiveLinkRow: View {
	let dive: Dive
	var topPadding: CGFloat = 12

	var body: some View {
		NavigationLink {
			DiveDetailView(dive: dive)
		} label: {
			HStack {
				Text(LocalizedStringKey(dive.displayTitle))
					.lineLimit(1)
				Spacer()
				Text(dive.date.formatted(date: .abbreviated, time: .omitted))
					.lineLimit(1)
				Image(systemName: "chevron.right")
					.font(.caption)
			}
			.padding(.top, topPadding)
		}
		.buttonStyle(.plain)
	}
}
