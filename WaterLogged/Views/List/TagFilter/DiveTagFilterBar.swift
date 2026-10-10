//
//  DiveTagFilterBar.swift
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
import SwiftData

/// The strip of tag chips at the top of the dive list. Tapping a chip toggles whether dives must carry
/// that tag; dives must carry every selected tag to stay visible.
///
/// This is the dive list's first row rather than a separate view stacked above it. Stacking it in a
/// `VStack` alongside the `List` cost the column its search field and its collapsing large title —
/// `.searchable(placement: .sidebar)` and the navigation title both track the column's *root* scroll
/// view, and a `VStack` root gives them nothing to track. As a row it scrolls away with the content,
/// which is fine, and the list keeps `.appGradientScrollBackground()` so the gradient stays unbroken.
///
/// It paints no background of its own and removes itself entirely when no dive carries a tag, so a fresh
/// log book shows no empty strip.
///
/// This owns its own query so a dive edit only invalidates the strip rather than the whole split view.
/// The query covers *all* dives, not the filtered ones — the vocabulary has to keep offering tags whose
/// dives the current search or selection has hidden, or the filter would be impossible to widen again.
/// Only the `tags` column is fetched.
struct DiveTagFilterBar: View {
	@Binding var selectedTags: Set<String>

	@Query private var dives: [Dive]

	init(selectedTags: Binding<Set<String>>) {
		_selectedTags = selectedTags

		var descriptor = FetchDescriptor<Dive>()
		descriptor.propertiesToFetch = [\.tags]
		_dives = Query(descriptor)
	}

	private var vocabulary: [String] {
		DiveTagFilter.vocabulary(from: dives.map(\.tags))
	}

	var body: some View {
		if !vocabulary.isEmpty {
			ScrollView(.horizontal) {
				HStack(spacing: 8) {
					ForEach(vocabulary, id: \.self) { tag in
						TagFilterChip(tag: tag, isSelected: selectedTags.contains(tag)) {
							toggle(tag)
						}
					}
				}
				.padding(.vertical, 4)
			}
			// .never rather than .hidden: on macOS a scroller shows through .hidden when the system
			// is set to always show scroll bars, and it makes this thin strip noticeably taller.
			.scrollIndicators(.never)
			// The tag symbol and the clear button are bars rather than plain siblings in an HStack so
			// the chips scroll *under* them: `safeAreaBar` extends the scroll view's edge effect over
			// the inset, which fades chips out at both ends instead of cutting them off mid-word. The
			// system draws that fade, so unlike a `.mask` it costs nothing in hit testing.
			.scrollEdgeEffectStyle(.soft, for: .horizontal)
			.safeAreaBar(edge: .leading, spacing: 8) {
				Image(systemName: "tag")
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			.safeAreaBar(edge: .trailing, spacing: 8) {
				if !selectedTags.isEmpty {
					// Text kept for VoiceOver even though only the glyph shows.
					Button("Clear Tag Filter", systemImage: "xmark.circle.fill") {
						selectedTags.removeAll()
					}
					.labelStyle(.iconOnly)
					.buttonStyle(.plain)
					.foregroundStyle(.secondary)
				}
			}
			// No horizontal padding: as a list row it inherits the row insets, so the chips line up
			// with the leading edge of the dive tiles below.
		}
	}

	private func toggle(_ tag: String) {
		if selectedTags.contains(tag) {
			selectedTags.remove(tag)
		} else {
			selectedTags.insert(tag)
		}
	}
}

/// Shown the way `DiveListView` uses it: as the list's first row, over the list's app gradient.
#Preview("A tag selected") {
	@Previewable @State var selectedTags: Set<String> = ["reef"]
	@Previewable @State var searchText = ""

	NavigationStack {
		List {
			DiveTagFilterBar(selectedTags: $selectedTags)
				.listRowBackground(Color.clear)
				.listRowSeparator(.hidden)
			ForEach(1..<8) { row in
				Text("Dive row \(row)")
			}
			.tileListRowBackground()
		}
		.appGradientScrollBackground()
		.navigationTitle("Dives")
		// Here to prove the point in the type's doc comment: with the strip as a row the list is still
		// the root scroll view, so the search field and the large title both survive.
		.searchable(text: $searchText, prompt: "Search dives")
	}
	.modelContainer(PreviewContainer.container)
}

/// Nothing selected: the trailing clear bar should take no space at all, leaving the chips the full width.
#Preview("Nothing selected") {
	@Previewable @State var selectedTags: Set<String> = []

	NavigationStack {
		List {
			DiveTagFilterBar(selectedTags: $selectedTags)
				.listRowBackground(Color.clear)
				.listRowSeparator(.hidden)
			ForEach(1..<4) { row in
				Text("Dive row \(row)")
			}
			.tileListRowBackground()
		}
		.appGradientScrollBackground()
		.navigationTitle("Dives")
	}
	.modelContainer(PreviewContainer.container)
}
