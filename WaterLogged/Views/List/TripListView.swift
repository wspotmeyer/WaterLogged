//
//  TripListView.swift
//  WaterLogged
//
//  Created by John Meyer on 4/20/26.
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

private enum TripSortOrder: String {
	case newestFirst
	case oldestFirst

	var descriptors: [SortDescriptor<Trip>] {
		switch self {
			case .newestFirst: [SortDescriptor(\Trip.startDate, order: .reverse)]
			case .oldestFirst: [SortDescriptor(\Trip.startDate)]
		}
	}
}

struct TripListView: View {
	@Environment(\.modelContext) private var modelContext
	@AppStorage("tripSortOrder") private var sortOrder: TripSortOrder = .newestFirst
	@State private var searchText = ""
	@State private var selectedTrip: Trip?
	@State private var showingAddTrip = false

	var body: some View {
		NavigationSplitView {
			TripListContent(sort: sortOrder.descriptors, searchText: searchText, selectedTrip: $selectedTrip)
				.navigationTitle("Trips")
#if os(macOS)
				.navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 400)
#endif
				.toolbar {
					ToolbarItem {
						Button("Add Trip", systemImage: "plus") {
							showingAddTrip = true
						}
					}
					ToolbarSpacer()
					ToolbarItem {
						Menu("Sort", systemImage: "line.3.horizontal.decrease") {
							Picker("Sort", selection: $sortOrder) {
								Text("Newest First")
									.tag(TripSortOrder.newestFirst)
								Text("Oldest First")
									.tag(TripSortOrder.oldestFirst)
							}
							.pickerStyle(.inline)
						}
					}
				}
				.sheet(isPresented: $showingAddTrip) {
					TripEntryView(trip: nil)
				}
		} detail: {
			if let trip = selectedTrip {
				NavigationStack {
					TripDetailView(trip: trip) {
						selectedTrip = nil
					}
				}
				.id(selectedTrip?.persistentModelID)
			} else {
				AllSitesMapView {
					ContentUnavailableView(
						"Select a Trip",
						systemImage: "airplane.path.dotted",
						description: Text("Choose a trip from the list to view its details.")
					)
				}
				.overlay(alignment: .bottom) {
					Text("Choose a trip from the list to view its details")
						.font(.headline)
						.padding(.horizontal)
						.padding(.vertical, 8)
						.glassEffect()
						.padding(.bottom)
				}
			}
		}
		.ignoresSafeArea(edges: .top)
		.searchable(text: $searchText, placement: .sidebar, prompt: "Search trips")
		.onChange(of: NavigationRouter.shared.pending, initial: true) { _, pending in
			guard case let .trip(externalId) = pending else { return }
			var descriptor = FetchDescriptor<Trip>(predicate: #Predicate { $0.externalId == externalId })
			descriptor.fetchLimit = 1
			if let trip = try? modelContext.fetch(descriptor).first {
				selectedTrip = trip
			}
			NavigationRouter.shared.pending = nil
		}
	}
}

// MARK: - Child view that owns the @Query

private struct TripListContent: View {
	@Environment(\.modelContext) private var modelContext
#if os(iOS)
	@Environment(\.verticalSizeClass) private var verticalSizeClass
#endif
	@Query var trips: [Trip]
	@Binding var selectedTrip: Trip?
	@State private var pendingDeleteOffsets: IndexSet?
	private let searchText: String

	private var hasIndex: Bool {
		trips.count > YearIndexBar.minimumTripCount
	}

	/// Show the condensed (dotted) index only where the years will not fit — a landscape phone, where
	/// the vertical size class is compact. Tall layouts (portrait, iPad, macOS) get every year.
	private var indexCondensed: Bool {
#if os(iOS)
		verticalSizeClass == .compact
#else
		false
#endif
	}

	private var indexEntries: [YearIndexBar.Entry] {
		trips.map {
			YearIndexBar.Entry(id: $0.persistentModelID, year: Calendar.current.component(.year, from: $0.startDate))
		}
	}

	init(sort: [SortDescriptor<Trip>], searchText: String, selectedTrip: Binding<Trip?>) {
		_selectedTrip = selectedTrip
		self.searchText = searchText
		_trips = Query(filter: #Predicate<Trip> {
			if searchText.isEmpty {
				return true
			} else {
				return $0.name.localizedStandardContains(searchText)
				|| $0.location.localizedStandardContains(searchText)
				|| $0.address.localizedStandardContains(searchText)
				|| $0.notes.localizedStandardContains(searchText)
			}
		}, sort: sort)
	}

	var body: some View {
		Group {
			if trips.isEmpty && searchText.isEmpty {
				ContentUnavailableView(
					"No Trips Yet",
					systemImage: "airplane.path.dotted",
					description: Text("Tap + to add your first trip.")
				)
			} else if trips.isEmpty {
				ContentUnavailableView(
					"No Results for \"\(searchText)\"",
					systemImage: "magnifyingglass",
					description: Text("No trip name, address, location, or notes contains the given text.")
				)
			} else {
				List(selection: $selectedTrip) {
					ForEach(trips) { trip in
						TripRowView(trip: trip)
							.tag(trip)
					}
					.onDelete { offsets in
						pendingDeleteOffsets = offsets
					}
					.tileListRowBackground()
				}
				.appGradientScrollBackground()
				.indexShelf(isAvailable: hasIndex) { scrollTo in
					YearIndexBar(entries: indexEntries, condensed: indexCondensed) { entry in
						scrollTo(entry.id)
					}
				}
			}
		}
		.alert(
			"Delete Trip",
			isPresented: Binding(
				get: { pendingDeleteOffsets != nil },
				set: { if !$0 { pendingDeleteOffsets = nil } }
			)
		) {
			Button("Delete", role: .destructive) {
				if let offsets = pendingDeleteOffsets {
					deleteTrips(at: offsets)
				}
				pendingDeleteOffsets = nil
			}
			Button("Cancel", role: .cancel) {
				pendingDeleteOffsets = nil
			}
		} message: {
			if let offsets = pendingDeleteOffsets {
				let count = offsets.count
				Text("Are you sure you want to delete \(count == 1 ? "this trip" : "these \(count) trips")? This cannot be undone.")
			}
		}
	}

	private func deleteTrips(at offsets: IndexSet) {
		for index in offsets {
			let trip = trips[index]
			if selectedTrip == trip {
				selectedTrip = nil
			}
			modelContext.delete(trip)
		}
	}
}

// MARK: - Row View

private struct TripRowView: View {
	let trip: Trip

	var body: some View {
		HStack(spacing: 12) {
			VStack(alignment: .leading, spacing: 4) {
				HStack {
					Text(trip.name)
						.font(.headline)
						.lineLimit(1)
					Spacer()
					if let dives = trip.dives, !dives.isEmpty {
						DiveCount(count: dives.count, font: .headline)
					}
				}
				HStack {
					if !trip.location.isEmpty {
						Label(trip.location, systemImage: "map")
							.foregroundStyle(.secondary)
							.lineLimit(1)
					}
					Spacer()
					if !trip.urlString.isEmpty {
						Image(systemName: "link")
							.foregroundStyle(.secondary)
					}
				}
				.labelStyle(.listRow)
				.font(.caption2)
				Text(trip.dateRangeFormatted)
					.font(.caption2)
					.foregroundStyle(.tertiary)
			}
		}
#if os(macOS)
		.padding(.vertical, 4)
#endif
		.alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
	}
}

#Preview {
	TripListView()
		.environment(SharedMapState())
		.modelContainer(PreviewContainer.container)
}
