//
//  DiveListView.swift
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
import SwiftData
import MapKit

private enum DiveSortOrder: String {
	case newestFirst
	case oldestFirst

	var descriptors: [SortDescriptor<Dive>] {
		switch self {
			case .newestFirst: [
				SortDescriptor(\Dive.date, order: .reverse),
				SortDescriptor(\Dive.diveNumber, order: .reverse)
			]
			case .oldestFirst: [
				SortDescriptor(\Dive.date),
				SortDescriptor(\Dive.diveNumber)
			]
		}
	}
}

struct DiveListView: View {
	@Environment(\.modelContext) private var modelContext
	@AppStorage("diveSortOrder") private var sortOrder: DiveSortOrder = .newestFirst
	@State private var searchText = ""
	@State private var selectedDive: Dive?
	@State private var showingEntry = false
	@State private var columnVisibility: NavigationSplitViewVisibility = .all
	@State private var selectedTags: Set<String> = []

	var body: some View {
		NavigationSplitView(columnVisibility: $columnVisibility) {
			// The list is the column's root view on purpose: `.searchable(placement: .sidebar)` and the
			// collapsing large title both track the root scroll view, and wrapping this in a stack to
			// make room for the tag strip loses both. The strip is a row inside the list instead.
			DiveListContent(
				sort: sortOrder.descriptors,
				searchText: searchText,
				selectedTags: $selectedTags,
				selectedDive: $selectedDive
			)
			.navigationTitle("Dives")
#if os(macOS)
			.navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 400)
#endif
			.toolbar {
				ToolbarItem {
					Button {
						showingEntry = true
					} label: {
						Label("Log Dive", systemImage: "plus")
					}
				}
				ToolbarSpacer()
				ToolbarItem {
					Menu("Sort", systemImage: "line.3.horizontal.decrease") {
						Picker("Sort", selection: $sortOrder) {
							Text("Newest First")
								.tag(DiveSortOrder.newestFirst)
							Text("Oldest First")
								.tag(DiveSortOrder.oldestFirst)
						}
						.pickerStyle(.inline)
					}
				}
			}
			.sheet(isPresented: $showingEntry) {
				DiveEntryView(dive: nil)
			}
		} detail: {
			if let dive = selectedDive {
				NavigationStack {
					DiveDetailView(dive: dive) {
						selectedDive = nil
					}
				}
			} else {
				AllSitesMapView {
					ContentUnavailableView(
						"Select a Dive",
						systemImage: "list.bullet.clipboard",
						description: Text("Choose a dive from the list to view its details.")
					)
				}
				.overlay(alignment: .bottom) {
					Text("Choose a dive from the list to view its details")
						.font(.headline)
						.padding(.horizontal)
						.padding(.vertical, 8)
						.glassEffect()
						.padding(.bottom)
				}
			}
		}
		.ignoresSafeArea(edges: .top)
		.searchable(text: $searchText, placement: .sidebar, prompt: "Search dives")
		.onChange(of: NavigationRouter.shared.pending, initial: true) { _, pending in
			guard case let .dive(externalId) = pending else { return }
			var descriptor = FetchDescriptor<Dive>(predicate: #Predicate { $0.externalId == externalId })
			descriptor.fetchLimit = 1
			if let dive = try? modelContext.fetch(descriptor).first {
				selectedDive = dive
			}
			NavigationRouter.shared.pending = nil
		}
	}
}

// MARK: - Child view that owns the @Query (re-created when sort/search change)

private struct DiveListContent: View {
	@Environment(\.modelContext) private var modelContext
	@Query var dives: [Dive]
	@Binding var selectedTags: Set<String>
	@Binding var selectedDive: Dive?
	@State private var pendingDeleteDive: Dive?
	private let searchText: String

	/// The dives left after the tag filter narrows the query's results.
	///
	/// The tag conjunction runs here rather than in the predicate above: SwiftData translates a fixed
	/// number of `tags.contains(_:)` terms, but not a count only known at runtime. See `DiveTagFilter`.
	private var visibleDives: [Dive] {
		DiveTagFilter.filtered(dives, selecting: selectedTags)
	}

	private var hasIndex: Bool {
		visibleDives.count > DiveNumberIndexBar.minimumDiveCount
	}

	private var indexEntries: [DiveNumberIndexBar.Entry] {
		visibleDives.map { DiveNumberIndexBar.Entry(id: $0.persistentModelID, number: $0.diveNumber) }
	}

	init(
		sort: [SortDescriptor<Dive>],
		searchText: String,
		selectedTags: Binding<Set<String>>,
		selectedDive: Binding<Dive?>
	) {
		_selectedTags = selectedTags
		_selectedDive = selectedDive
		self.searchText = searchText
		_dives = Query(filter: #Predicate<Dive> {
			if searchText.isEmpty {
				return true
			} else {
				return $0.title.localizedStandardContains(searchText)
				|| $0.notes.localizedStandardContains(searchText)
				|| ($0.site?.name.localizedStandardContains(searchText) ?? false)
				|| ($0.site?.region.localizedStandardContains(searchText) ?? false)
				|| ($0.site?.country.localizedStandardContains(searchText) ?? false)
			}
		}, sort: sort)
	}

	var body: some View {
		Group {
			if visibleDives.isEmpty {
				DiveListEmptyState(
					searchText: searchText,
					selectedTags: $selectedTags,
					logbookIsEmpty: dives.isEmpty && searchText.isEmpty
				)
			} else {
				List(selection: $selectedDive) {
					DiveTagFilterBar(selectedTags: $selectedTags)
						// Chrome, not a dive: no separator and it must never take the
						// list's selection or a tap on a chip would also open a dive.
						.tileListRowBackground()
						.listRowSeparator(.hidden)
						.selectionDisabled()
					ForEach(visibleDives) { dive in
						DiveRowView(dive: dive)
							.tag(dive)
							.swipeActions(edge: .trailing, allowsFullSwipe: false) {
								Button("Delete", systemImage: "trash", role: .destructive) {
									pendingDeleteDive = dive
								}
							}
					}
					.tileListRowBackground()
				}
				.appGradientScrollBackground()
				.indexShelf(isAvailable: hasIndex) { scrollTo in
					DiveNumberIndexBar(entries: indexEntries) { entry in
						scrollTo(entry.id)
					}
				}
			}
		}
		.alert(
			"Delete Dive?",
			isPresented: Binding(
				get: { pendingDeleteDive != nil },
				set: { if !$0 { pendingDeleteDive = nil } }
			)
		) {
			Button("Delete", systemImage: "trash", role: .destructive) {
				if let dive = pendingDeleteDive {
					deleteDive(dive)
				}
				pendingDeleteDive = nil
			}
			Button("Cancel", systemImage: "xmark", role: .cancel) {
				pendingDeleteDive = nil
			}
		} message: {
			if let dive = pendingDeleteDive {
				Text("Are you sure you want to delete \"\(dive.displayTitle)\"? This cannot be undone.")
			}
		}
	}

	private func deleteDive(_ dive: Dive) {
		if selectedDive == dive {
			selectedDive = nil
		}
		modelContext.delete(dive)
	}
}

// MARK: - Row View

private struct DiveRowView: View {
	let dive: Dive
	@AppStorage("unitSystem") private var unitSystem: UnitSystem = .imperial

	private var units: UnitFormatter { UnitFormatter(system: unitSystem) }

	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			DiveRowHeader(dive: dive)

			HStack(spacing: 15) {
				Label(units.depthString(dive.maxDepthMeters, decimals: 0), systemImage: "arrow.down.to.line")
				Label(dive.durationFormatted, systemImage: "clock")
				if let site = dive.site {
					Label(LocalizedStringKey(site.name), systemImage: "mappin.and.ellipse")
						.lineLimit(1)
				}
			}
			.labelStyle(.listRow)
			.font(.caption)
			.foregroundStyle(.secondary)

			HStack(spacing: 8) {
				Text(dive.date.formatted(date: .abbreviated, time: .shortened))
					.foregroundStyle(.tertiary)
				Spacer()
				if let certification = dive.certification, !certification.isDeleted {
					Image(systemName: "graduationcap")
						.foregroundStyle(.secondary)
				}
				if let logbook = dive.logbookImageData, !logbook.isEmpty {
					Image(systemName: "book.fill")
						.foregroundStyle(.secondary)
				}
				if !dive.notes.isEmpty {
					Image(systemName: "text.page")
						.foregroundStyle(.secondary)
				}
				if let signature = dive.verificationSignatureData, !signature.isEmpty {
					Image(systemName: "signature")
						.foregroundStyle(.secondary)
				}
				if let _ = dive.startLatitude, let _ = dive.startLongitude, let _ = dive.endLatitude, let _ = dive.endLongitude {
					Image(systemName: "location.fill")
						.foregroundStyle(.secondary)
				}
				if let diveProfile = dive.diveProfile, !diveProfile.isEmpty {
					Image(systemName: "chart.xyaxis.line")
						.foregroundStyle(.secondary)
				}
				if let photos = dive.photos, !photos.isEmpty {
					Image(systemName: "photo")
						.foregroundStyle(.secondary)
				}
			}
			.font(.caption2)

			if !dive.tags.isEmpty {
				TagsListView(tags: dive.tags)
			}
		}
#if os(macOS)
		.padding(.vertical, 4)
#endif
		.alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
	}
}

/// The dive number, title, and rating at the top of a dive row.
///
/// At accessibility text sizes the badge is stacked above the title: it grows too wide at those
/// sizes to leave the title room, and cross-row alignment stops mattering once each row reads as a
/// single column.
private struct DiveRowHeader: View {
	let dive: Dive

	@Environment(\.dynamicTypeSize) private var dynamicTypeSize

	var body: some View {
		if dynamicTypeSize.isAccessibilitySize {
			VStack(alignment: .leading, spacing: 4) {
				DiveNumberBadge(diveNumber: dive.diveNumber)
				// The title gets a second line here: at these sizes one line truncates almost
				// every site name.
				Text(LocalizedStringKey(dive.displayTitle))
					.font(.headline)
					.lineLimit(2)
				if dive.rating > 0 {
					StarRatingView(rating: dive.rating, interactive: false)
				}
			}
		} else {
			HStack {
				DiveNumberBadge(diveNumber: dive.diveNumber)
				Text(LocalizedStringKey(dive.displayTitle))
					.font(.headline)
					.lineLimit(1)
				Spacer()
				if dive.rating > 0 {
					StarRatingView(rating: dive.rating, interactive: false)
				}
			}
		}
	}
}

#Preview {
	DiveListView()
		.environment(SharedMapState())
		.modelContainer(PreviewContainer.container)
}
