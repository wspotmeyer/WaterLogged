//
//  ListDetailPlaceholder.swift
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

/// The detail column of a list's `NavigationSplitView` before anything is
/// selected: the all-sites map with a glass caption asking for a selection.
/// `title`, `systemImage` and `description` describe the fallback shown when
/// there are no sites to map.
struct ListDetailPlaceholder: View {
	let title: LocalizedStringKey
	let systemImage: String
	let description: LocalizedStringKey
	let caption: LocalizedStringKey

	var body: some View {
		AllSitesMapView {
			ContentUnavailableView(
				title,
				systemImage: systemImage,
				description: Text(description)
			)
		}
		.overlay(alignment: .bottom) {
			Text(caption)
				.font(.headline)
				.padding(.horizontal)
				.padding(.vertical, 8)
				.glassEffect()
				.padding(.bottom)
		}
	}
}
