//
//  BuddyListView.swift
//  WaterLogged
//
//  Created by John Meyer on 4/4/26.
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

private enum BuddySortOrder: String {
	case givenName
	case familyName
}

struct BuddyListView: View {
	@Environment(\.modelContext) private var modelContext
	@AppStorage("buddySortOrder") private var sortOrder: BuddySortOrder = .givenName
	@State private var searchText = ""
	@State private var selectedBuddy: Buddy?
	@State private var showingAddBuddy = false

	var body: some View {
		NavigationSplitView {
			BuddyListContent(sortOrder: sortOrder, searchText: searchText, selectedBuddy: $selectedBuddy)
				.navigationTitle("Buddies")
#if os(macOS)
				.navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 400)
#endif
				.toolbar {
					ToolbarItem {
						Button("Add Buddy", systemImage: "plus") {
							showingAddBuddy = true
						}
					}
					ToolbarSpacer()
					ToolbarItem {
						Menu("Sort", systemImage: "line.3.horizontal.decrease") {
							Picker("Sort", selection: $sortOrder) {
								Text("Given Name")
									.tag(BuddySortOrder.givenName)
								Text("Family Name")
									.tag(BuddySortOrder.familyName)
							}
							.pickerStyle(.inline)
						}
					}
				}
				.sheet(isPresented: $showingAddBuddy) {
					BuddyEntryView(buddy: nil)
				}
		} detail: {
			if let buddy = selectedBuddy {
				NavigationStack {
					BuddyDetailView(buddy: buddy) {
						selectedBuddy = nil
					}
				}
			} else {
				ListDetailPlaceholder(
					title: "Select a Buddy",
					systemImage: "person.2",
					description: "Choose a buddy from the list to view their details.",
					caption: "Choose a buddy from the list to view their details"
				)
			}
		}
		.ignoresSafeArea(edges: .top)
		.searchable(text: $searchText, placement: .sidebar, prompt: "Search buddies")
		.onChange(of: NavigationRouter.shared.pending, initial: true) { _, pending in
			guard case let .buddy(externalId) = pending else { return }
			let descriptor = FetchDescriptor<Buddy>(predicate: #Predicate { $0.externalId == externalId })
			if let buddy = try? modelContext.fetchFirst(descriptor) {
				selectedBuddy = buddy
			}
			NavigationRouter.shared.pending = nil
		}
	}
}

// MARK: - Child view that owns the @Query

private struct BuddyListContent: View {
	@Environment(\.modelContext) private var modelContext
	@Query var buddies: [Buddy]
	@Binding var selectedBuddy: Buddy?
	@State private var pendingDeleteOffsets: IndexSet?
	private let searchText: String
	private let sortOrder: BuddySortOrder

	init(sortOrder: BuddySortOrder, searchText: String, selectedBuddy: Binding<Buddy?>) {
		_selectedBuddy = selectedBuddy
		self.searchText = searchText
		self.sortOrder = sortOrder
		_buddies = Query(filter: #Predicate<Buddy> {
			if searchText.isEmpty {
				return true
			} else {
				return $0.givenName.localizedStandardContains(searchText)
				|| $0.familyName.localizedStandardContains(searchText)
			}
		})
	}

	private var sortedBuddies: [Buddy] {
		buddies.sorted { lhs, rhs in
			compare(lhs, rhs) == .orderedAscending
		}
	}

	/// Sorts on the chosen name field, falling back to the other name field when the primary field matches.
	private func compare(_ lhs: Buddy, _ rhs: Buddy) -> ComparisonResult {
		let givenOrder = lhs.givenName.markdownStripped.localizedStandardCompare(rhs.givenName.markdownStripped)
		let familyOrder = lhs.familyName.markdownStripped.localizedStandardCompare(rhs.familyName.markdownStripped)
		switch sortOrder {
			case .givenName:
				return givenOrder == .orderedSame ? familyOrder : givenOrder
			case .familyName:
				return familyOrder == .orderedSame ? givenOrder : familyOrder
		}
	}

	var body: some View {
		Group {
			if buddies.isEmpty && searchText.isEmpty {
				ContentUnavailableView(
					"No Buddies Yet",
					systemImage: "person.2",
					description: Text("Tap + to add your first dive buddy.")
				)
			} else if buddies.isEmpty {
				ContentUnavailableView(
					"No Results for \"\(searchText)\"",
					systemImage: "magnifyingglass",
					description: Text("No buddy name contains the given text.")
				)
			} else {
				List(selection: $selectedBuddy) {
					ForEach(sortedBuddies) { buddy in
						BuddyRowView(buddy: buddy)
							.tag(buddy)
					}
					.onDelete { offsets in
						pendingDeleteOffsets = offsets
					}
					.tileListRowBackground()
				}
				.appGradientScrollBackground()
			}
		}
		.deleteOffsetsConfirmation(
			"Delete Buddy",
			offsets: $pendingDeleteOffsets,
			message: { count in
				Text("Are you sure you want to delete \(count == 1 ? "this buddy" : "these \(count) buddies")? This cannot be undone.")
			},
			onDelete: deleteBuddies(at:)
		)
	}

	private func deleteBuddies(at offsets: IndexSet) {
		let items = sortedBuddies
		for index in offsets {
			let buddy = items[index]
			if selectedBuddy == buddy {
				selectedBuddy = nil
			}
			modelContext.delete(buddy)
		}
	}
}

// MARK: - Row View

private struct BuddyRowView: View {
	let buddy: Buddy

	var body: some View {
		if buddy.isLive {
			HStack {
				BuddyPhoto(photoData: buddy.photoData, size: 32)
				Text(buddy.formattedName)
					.font(.headline)
					.foregroundStyle(buddy.isRetired ? .tertiary : .primary)
					.lineLimit(1)
				Spacer()
				if let dives = buddy.dives, !dives.isEmpty {
					DiveCount(count: dives.count, font: .headline)
				}
			}
			.alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
		}
	}
}

#Preview {
	BuddyListView()
		.environment(SharedMapState())
		.modelContainer(PreviewContainer.container)
}
