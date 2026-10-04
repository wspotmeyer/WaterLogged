//
//  GasMixListView.swift
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

//
//  GasMixListView.swift
//  WaterLogged
//
//  Created by John Meyer on 3/27/26.
//

import SwiftUI
import SwiftData

struct GasMixListView: View {
	@Environment(\.modelContext) private var modelContext
	@State private var searchText = ""
	@State private var selectedGasMix: GasMix?
	@State private var showingAddGasMix = false

	var body: some View {
		NavigationSplitView {
			GasMixListContent(searchText: searchText, selectedGasMix: $selectedGasMix)
				.navigationTitle("Gas Mixes")
#if os(macOS)
				.navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 400)
#endif
				.toolbar {
					ToolbarItem(placement: .primaryAction) {
						Button("Add Gas Mix", systemImage: "plus") {
							showingAddGasMix = true
						}
					}
				}
				.sheet(isPresented: $showingAddGasMix) {
					GasMixEntryView(gasMix: nil)
				}
		} detail: {
			if let gasMix = selectedGasMix {
				NavigationStack {
					GasMixDetailView(gasMix: gasMix)
				}
			} else {
				AllSitesMapView {
					ContentUnavailableView(
						"Select a Gas Mix",
						systemImage: "aqi.medium",
						description: Text("Choose a gas mix from the list to view its details.")
					)
				}
				.overlay(alignment: .bottom) {
					Text("Choose a gas mix from the list to view its details")
						.font(.headline)
						.padding(.horizontal)
						.padding(.vertical, 8)
						.glassEffect()
						.padding(.bottom)
				}
			}
		}
		.ignoresSafeArea(edges: .top)
		.searchable(text: $searchText, placement: .sidebar, prompt: "Search gas mixes")
	}
}

// MARK: - Child view that owns the @Query

private struct GasMixListContent: View {
	@Environment(\.modelContext) private var modelContext
	@Query var gasMixes: [GasMix]
	@Binding var selectedGasMix: GasMix?
	@State private var pendingDeleteOffsets: IndexSet?
	private let searchText: String

	init(searchText: String, selectedGasMix: Binding<GasMix?>) {
		_selectedGasMix = selectedGasMix
		self.searchText = searchText
		_gasMixes = Query(filter: #Predicate<GasMix> {
			if searchText.isEmpty {
				return true
			} else {
				return $0.name.localizedStandardContains(searchText)
			}
		})
	}

	private var sortedGasMixes: [GasMix] {
		gasMixes.sorted { lhs, rhs in
			lhs.name.markdownStripped.localizedStandardCompare(rhs.name.markdownStripped) == .orderedAscending
		}
	}

	var body: some View {
		Group {
			if gasMixes.isEmpty && searchText.isEmpty {
				ContentUnavailableView(
					"No Gas Mixes Yet",
					systemImage: "aqi.medium",
					description: Text("Tap + to add your first gas mix.")
				)
			} else if gasMixes.isEmpty {
				ContentUnavailableView(
					"No Results for \"\(searchText)\"",
					systemImage: "magnifyingglass",
					description: Text("No gas mix name contains the given text.")
				)
			} else {
				List(selection: $selectedGasMix) {
					ForEach(sortedGasMixes) { mix in
						GasMixRowView(gasMix: mix)
							.tag(mix)
					}
					.onDelete { offsets in
						pendingDeleteOffsets = offsets
					}
					.tileListRowBackground()
				}
				.appGradientScrollBackground()
			}
		}
		.alert(
			"Delete Gas Mix",
			isPresented: Binding(
				get: { pendingDeleteOffsets != nil },
				set: { if !$0 { pendingDeleteOffsets = nil } }
			)
		) {
			Button("Delete", role: .destructive) {
				if let offsets = pendingDeleteOffsets {
					deleteGasMixes(at: offsets)
				}
				pendingDeleteOffsets = nil
			}
			Button("Cancel", role: .cancel) {
				pendingDeleteOffsets = nil
			}
		} message: {
			if let offsets = pendingDeleteOffsets {
				let count = offsets.count
				Text("Are you sure you want to delete \(count == 1 ? "this gas mix" : "these \(count) gas mixes")? This cannot be undone.")
			}
		}
	}

	private func deleteGasMixes(at offsets: IndexSet) {
		let mixes = sortedGasMixes
		for index in offsets {
			let mix = mixes[index]
			if selectedGasMix == mix {
				selectedGasMix = nil
			}
			modelContext.delete(mix)
		}
	}
}

// MARK: - Row View

private struct GasMixRowView: View {
	let gasMix: GasMix

	var body: some View {
		HStack(spacing: 12) {
			VStack(alignment: .leading, spacing: 4) {
				Text(gasMix.displayName)
					.font(.headline)
				Text(gasMix.componentSummary)
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			.padding(.vertical, 4)
			Spacer()
			let diveCount = Set((gasMix.tanks ?? []).compactMap(\.dive)).count
			if diveCount > 0 {
				DiveCount(count: diveCount, font: .headline)
			}
		}
#if os(macOS)
		.padding(.vertical, 4)
#endif
		.alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
	}
}

#Preview {
	GasMixListView()
		.environment(SharedMapState())
		.modelContainer(PreviewContainer.container)
}
