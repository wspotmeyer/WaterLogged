//
//  DiveSiteListView.swift
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
//  DiveSiteListView.swift
//  WaterLogged
//
//  Created by John Meyer on 2/24/26.
//

import SwiftUI
import SwiftData

private enum DiveSiteSortOrder: String {
	case name
	case country
	case region
}

struct DiveSiteListView: View {
	@Environment(\.modelContext) private var modelContext
	@AppStorage("diveSiteSortOrder") private var sortOrder: DiveSiteSortOrder = .name
	@State private var searchText = ""
	@State private var selectedSite: DiveSite?
	@State private var showingAddSite = false

	var body: some View {
		NavigationSplitView {
			DiveSiteListContent(sortOrder: sortOrder, searchText: searchText, selectedSite: $selectedSite)
				.navigationTitle("Dive Sites")
#if os(macOS)
				.navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 400)
#endif
				.toolbar {
					ToolbarItem {
						Button {
							showingAddSite = true
						} label: {
							Label("Add Site", systemImage: "plus")
						}
					}
					ToolbarSpacer()
					ToolbarItem {
						Menu("Sort", systemImage: "line.3.horizontal.decrease") {
							Picker("Sort", selection: $sortOrder) {
								Text("Name")
									.tag(DiveSiteSortOrder.name)
								Text("Country")
									.tag(DiveSiteSortOrder.country)
								Text("Region")
									.tag(DiveSiteSortOrder.region)
							}
							.pickerStyle(.inline)
						}
					}
				}
				.sheet(isPresented: $showingAddSite) {
					DiveSiteEntryView(site: nil)
				}
		} detail: {
			if let site = selectedSite {
				NavigationStack {
					DiveSiteDetailView(site: site) {
						selectedSite = nil
					}
				}
			} else {
				AllSitesMapView {
					ContentUnavailableView(
						"Select a Dive Site",
						systemImage: "mappin.and.ellipse",
						description: Text("Choose a dive site from the list to view its details.")
					)
				}
				.overlay(alignment: .bottom) {
					Text("Choose a dive site from the list to view its details")
						.font(.headline)
						.padding(.horizontal)
						.padding(.vertical, 8)
						.glassEffect()
						.padding(.bottom)
				}
			}
		}
		.ignoresSafeArea(edges: .top)
		.searchable(text: $searchText, placement: .sidebar, prompt: "Search sites")
		.onChange(of: NavigationRouter.shared.pending, initial: true) { _, pending in
			guard case let .diveSite(externalId) = pending else { return }
			var descriptor = FetchDescriptor<DiveSite>(predicate: #Predicate { $0.externalId == externalId })
			descriptor.fetchLimit = 1
			if let site = try? modelContext.fetch(descriptor).first {
				selectedSite = site
			}
			NavigationRouter.shared.pending = nil
		}
	}
}

// MARK: - Child view that owns the @Query

private struct DiveSiteListContent: View {
	@Environment(\.modelContext) private var modelContext
#if os(iOS)
	@Environment(\.verticalSizeClass) private var verticalSizeClass
#endif
	@Query var sites: [DiveSite]
	@Binding var selectedSite: DiveSite?
	@State private var pendingDeleteOffsets: IndexSet?
	private let searchText: String
	private let sortOrder: DiveSiteSortOrder

	private var hasIndex: Bool {
		sites.count > LetterIndexBar.minimumRowCount
	}

	/// Show the condensed (dotted) index only where the alphabet will not fit — a landscape phone,
	/// where the vertical size class is compact. Tall layouts (portrait, iPad, macOS) get all 26 letters.
	private var indexCondensed: Bool {
#if os(iOS)
		verticalSizeClass == .compact
#else
		false
#endif
	}

	private var indexEntries: [LetterIndexBar.Entry] {
		sortedSites.map { LetterIndexBar.Entry(id: $0.persistentModelID, letter: sectionLetter(for: $0)) }
	}

	/// The letter a site is filed under, taken from the field the list is currently sorted by. Leading
	/// whitespace and Markdown are ignored and diacritics are folded, so "Éze" files under E; anything
	/// that does not start with a letter (a digit, symbol, or empty field) is bucketed under "#".
	private func sectionLetter(for site: DiveSite) -> Character {
		let field: String
		switch sortOrder {
			case .name: field = site.name
			case .country: field = site.country
			case .region: field = site.region
		}
		guard let first = field.markdownStripped.first(where: { !$0.isWhitespace }) else { return "#" }
		let folded = String(first).folding(options: .diacriticInsensitive, locale: .current).uppercased()
		if let letter = folded.first, letter.isLetter { return letter }
		return "#"
	}

	init(sortOrder: DiveSiteSortOrder, searchText: String, selectedSite: Binding<DiveSite?>) {
		_selectedSite = selectedSite
		self.searchText = searchText
		self.sortOrder = sortOrder
		_sites = Query(filter: #Predicate<DiveSite> {
			if searchText.isEmpty {
				return true
			} else {
				return $0.name.localizedStandardContains(searchText)
				|| $0.region.localizedStandardContains(searchText)
				|| $0.country.localizedStandardContains(searchText)
				|| $0.notes.localizedStandardContains(searchText)
			}
		})
	}

	private var sortedSites: [DiveSite] {
		sites.sorted { lhs, rhs in
			compare(lhs, rhs) == .orderedAscending
		}
	}

	private func compare(_ lhs: DiveSite, _ rhs: DiveSite) -> ComparisonResult {
		let nameOrder = lhs.name.markdownStripped.localizedStandardCompare(rhs.name.markdownStripped)
		switch sortOrder {
			case .name:
				return nameOrder
			case .country:
				let primary = lhs.country.markdownStripped.localizedStandardCompare(rhs.country.markdownStripped)
				return primary == .orderedSame ? nameOrder : primary
			case .region:
				let primary = lhs.region.markdownStripped.localizedStandardCompare(rhs.region.markdownStripped)
				return primary == .orderedSame ? nameOrder : primary
		}
	}

	var body: some View {
		Group {
			if sites.isEmpty && searchText.isEmpty {
				ContentUnavailableView(
					"No Dive Sites Yet",
					systemImage: "mappin.slash",
					description: Text("Tap + to add your first dive site.")
				)
			} else if sites.isEmpty {
				ContentUnavailableView(
					"No Results for \"\(searchText)\"",
					systemImage: "magnifyingglass",
					description: Text("No dive site name, region, country, or notes contains the given text.")
				)
			} else {
				List(selection: $selectedSite) {
					ForEach(sortedSites) { site in
						DiveSiteRowView(site: site)
							.tag(site)
					}
					.onDelete { offsets in
						pendingDeleteOffsets = offsets
					}
					.tileListRowBackground()
				}
				.appGradientScrollBackground()
				.indexShelf(isAvailable: hasIndex) { scrollTo in
					LetterIndexBar(entries: indexEntries, condensed: indexCondensed) { entry in
						scrollTo(entry.id)
					}
				}
			}
		}
		.alert(
			"Delete Dive Site",
			isPresented: Binding(
				get: { pendingDeleteOffsets != nil },
				set: { if !$0 { pendingDeleteOffsets = nil } }
			)
		) {
			Button("Delete", role: .destructive) {
				if let offsets = pendingDeleteOffsets {
					deleteSites(at: offsets)
				}
				pendingDeleteOffsets = nil
			}
			Button("Cancel", role: .cancel) {
				pendingDeleteOffsets = nil
			}
		} message: {
			if let offsets = pendingDeleteOffsets {
				let count = offsets.count
				Text("Are you sure you want to delete \(count == 1 ? "this dive site" : "these \(count) dive sites")? This cannot be undone.")
			}
		}
	}

	private func deleteSites(at offsets: IndexSet) {
		let items = sortedSites
		for index in offsets {
			let site = items[index]
			if selectedSite == site {
				selectedSite = nil
			}
			modelContext.delete(site)
		}
	}
}

// MARK: - Row View

private struct DiveSiteRowView: View {
	let site: DiveSite

	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			HStack(spacing: 4) {
				Text(LocalizedStringKey(site.name))
					.font(.headline)
					.lineLimit(1)
				Spacer()
				if let dives = site.dives, !dives.isEmpty {
					DiveCount(count: dives.count, font: .headline)
				}
			}
			HStack(spacing: 12) {
				if !site.region.isEmpty {
					Label(site.region, systemImage: "map")
						.lineLimit(1)
				}
				if !site.country.isEmpty {
					if let flag = CountryFlag.emoji(for: site.country) {
						Text("\(flag) \(site.country)")
							.lineLimit(1)
					} else {
						Label(site.country, systemImage: "globe")
							.lineLimit(1)
					}
				}
				Spacer()
				if !site.notes.isEmpty {
					Image(systemName: "text.page")
						.foregroundStyle(.secondary)
				}
				if let latitude = site.latitude, let longitude = site.longitude, !(latitude.isNaN && longitude.isNaN) {
					Image(systemName: "mappin.and.ellipse")
						.foregroundStyle(.secondary)
				}
				if let photos = site.photos, !photos.isEmpty {
					Image(systemName: "photo")
						.foregroundStyle(.secondary)
				}
			}
			.labelStyle(.listRow)
			.font(.caption)
			.foregroundStyle(.secondary)
		}
#if os(macOS)
		.padding(.vertical, 4)
#endif
		.alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
	}
}

#Preview {
	DiveSiteListView()
		.environment(SharedMapState())
		.modelContainer(PreviewContainer.container)
}
