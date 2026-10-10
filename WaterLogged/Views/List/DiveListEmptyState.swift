//
//  DiveListEmptyState.swift
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

/// What the dive list shows in place of its rows when there is nothing to show: an empty log book, a
/// search that matched nothing, or a tag filter that excluded everything.
///
/// These replace the `List`, which is what normally paints the app gradient, so this paints it itself —
/// otherwise the column drops to a flat system background exactly when the screen is emptiest.
struct DiveListEmptyState: View {

	/// The current search text, empty when the person isn't searching.
	let searchText: String

	/// The tags being filtered on. A binding because this view offers to clear them.
	@Binding var selectedTags: Set<String>

	/// True when the log book holds no dives at all, as opposed to the search or tags hiding them.
	let logbookIsEmpty: Bool

	var body: some View {
		Group {
			if logbookIsEmpty {
				ContentUnavailableView(
					"No Dives Yet",
					systemImage: "water.waves.and.arrow.trianglehead.down",
					description: Text("Tap + to log your first dive.")
				)
			} else if !selectedTags.isEmpty {
				ContentUnavailableView {
					Label("No Dives Match These Tags", systemImage: "tag.slash")
				} description: {
					if searchText.isEmpty {
						Text("No dive carries every selected tag.")
					} else {
						Text("No dive matching \"\(searchText)\" carries every selected tag.")
					}
				} actions: {
					Button("Clear Tag Filter", systemImage: "xmark.circle.fill") {
						selectedTags.removeAll()
					}
				}
			} else {
				ContentUnavailableView(
					"No Results for \"\(searchText)\"",
					systemImage: "magnifyingglass",
					description: Text("No dive title, dive notes, dive site name, or dive site region contains the given text.")
				)
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.appGradient()
	}
}

#Preview("Search found nothing") {
	@Previewable @State var selectedTags: Set<String> = []

	DiveListEmptyState(searchText: "thistlegorm", selectedTags: $selectedTags, logbookIsEmpty: false)
}

#Preview("Tags excluded everything") {
	@Previewable @State var selectedTags: Set<String> = ["wreck", "reef"]

	DiveListEmptyState(searchText: "", selectedTags: $selectedTags, logbookIsEmpty: false)
}

#Preview("Empty logbook") {
	@Previewable @State var selectedTags: Set<String> = []

	DiveListEmptyState(searchText: "", selectedTags: $selectedTags, logbookIsEmpty: true)
}
