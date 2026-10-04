//
//  EquipmentListView.swift
//  WaterLogged
//
//  Created by John Meyer on 3/28/26.
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

private enum EquipmentSortField: String {
	case name
	case purchaseDate
}

private enum EquipmentSortDirection: String {
	case ascending
	case descending
}

struct EquipmentListView: View {
	@AppStorage("equipmentSortField") private var sortField: EquipmentSortField = .name
	@AppStorage("equipmentSortDirection") private var sortDirection: EquipmentSortDirection = .ascending
	@State private var searchText = ""
	@State private var selectedEquipment: Equipment?
	@State private var showingAddEquipment = false

	var body: some View {
		NavigationSplitView {
			EquipmentListContent(sortField: sortField, sortDirection: sortDirection, searchText: searchText, selectedEquipment: $selectedEquipment)
				.navigationTitle("Equipment")
#if os(macOS)
				.navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 400)
#endif
				.toolbar {
					ToolbarItem {
						Button("Add Equipment", systemImage: "plus") {
							showingAddEquipment = true
						}
					}
					ToolbarSpacer()
					ToolbarItem {
						Menu("Sort", systemImage: "line.3.horizontal.decrease") {
							Picker("Sort By", selection: $sortField) {
								Text("Name")
									.tag(EquipmentSortField.name)
								Text("Purchase Date")
									.tag(EquipmentSortField.purchaseDate)
							}
							.pickerStyle(.inline)
							Picker("Order", selection: $sortDirection) {
								Text("Ascending")
									.tag(EquipmentSortDirection.ascending)
								Text("Descending")
									.tag(EquipmentSortDirection.descending)
							}
							.pickerStyle(.inline)
						}
					}
				}
				.sheet(isPresented: $showingAddEquipment) {
					EquipmentEntryView(equipment: nil)
				}
		} detail: {
			if let equipment = selectedEquipment {
				NavigationStack {
					EquipmentDetailView(equipment: equipment) {
						selectedEquipment = nil
					}
				}
			} else {
				ListDetailPlaceholder(
					title: "Select Equipment",
					systemImage: "briefcase",
					description: "Choose a piece of equipment from the list to view its details.",
					caption: "Choose a piece of equipment from the list to view its details"
				)
			}
		}
		.ignoresSafeArea(edges: .top)
		.searchable(text: $searchText, placement: .sidebar, prompt: "Search equipment")
	}
}

// MARK: - Child view that owns the @Query

private struct EquipmentListContent: View {
	@Environment(\.modelContext) private var modelContext
	@Query var equipment: [Equipment]
	@Binding var selectedEquipment: Equipment?
	@State private var pendingDeleteOffsets: IndexSet?
	private let searchText: String
	private let sortField: EquipmentSortField
	private let sortDirection: EquipmentSortDirection

	init(sortField: EquipmentSortField, sortDirection: EquipmentSortDirection, searchText: String, selectedEquipment: Binding<Equipment?>) {
		_selectedEquipment = selectedEquipment
		self.searchText = searchText
		self.sortField = sortField
		self.sortDirection = sortDirection
		_equipment = Query(filter: #Predicate<Equipment> {
			if searchText.isEmpty {
				return true
			} else {
				return $0.name.localizedStandardContains(searchText)
				|| $0.manufacturer.localizedStandardContains(searchText)
				|| $0.model.localizedStandardContains(searchText)
			}
		})
	}

	private var sortedEquipment: [Equipment] {
		equipment.sorted { lhs, rhs in
			let result = compare(lhs, rhs)
			return sortDirection == .ascending
			? result == .orderedAscending
			: result == .orderedDescending
		}
	}

	private func compare(_ lhs: Equipment, _ rhs: Equipment) -> ComparisonResult {
		switch sortField {
			case .name:
				return lhs.name.markdownStripped.localizedStandardCompare(rhs.name.markdownStripped)
			case .purchaseDate:
				let lDate = lhs.purchaseDate ?? .distantPast
				let rDate = rhs.purchaseDate ?? .distantPast
				if lDate < rDate { return .orderedAscending }
				if lDate > rDate { return .orderedDescending }
				return lhs.name.markdownStripped.localizedStandardCompare(rhs.name.markdownStripped)
		}
	}

	var body: some View {
		Group {
			if equipment.isEmpty && searchText.isEmpty {
				ContentUnavailableView(
					"No Equipment Yet",
					systemImage: "briefcase",
					description: Text("Tap + to add your first piece of equipment.")
				)
			} else if equipment.isEmpty {
				ContentUnavailableView(
					"No Results for \"\(searchText)\"",
					systemImage: "magnifyingglass",
					description: Text("No equipment name, model, or manufacturer contains the given text.")
				)
			} else {
				List(selection: $selectedEquipment) {
					ForEach(sortedEquipment) { item in
						EquipmentRowView(equipment: item)
							.tag(item)
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
			"Delete Equipment",
			offsets: $pendingDeleteOffsets,
			message: { count in
				Text("Are you sure you want to delete \(count == 1 ? "this equipment" : "these \(count) items")? This cannot be undone.")
			},
			onDelete: deleteEquipment(at:)
		)
	}

	private func deleteEquipment(at offsets: IndexSet) {
		let items = sortedEquipment
		for index in offsets {
			let item = items[index]
			if selectedEquipment == item {
				selectedEquipment = nil
			}
			modelContext.delete(item)
		}
	}
}

// MARK: - Row View

private struct EquipmentRowView: View {
	let equipment: Equipment

	var body: some View {
		HStack(spacing: 12) {
			VStack(alignment: .leading, spacing: 4) {
				HStack {
					EquipmentTypeIcon(type: equipment.resolvedType)
						.foregroundStyle(.secondary)
						.frame(width: 24)
					Text(equipment.name)
						.font(.headline)
						.foregroundStyle(equipment.isRetired ? .tertiary : .primary)
						.lineLimit(1)
					Spacer()
					if let dives = equipment.dives, !dives.isEmpty {
						DiveCount(count: dives.count, font: .headline)
					}
				}
				HStack {
					if !equipment.manufacturer.isEmpty {
						Text(equipment.manufacturer)
							.foregroundStyle(equipment.isRetired ? .tertiary : .secondary)
							.lineLimit(1)
					}
					Spacer()
					if equipment.autoAddToDives {
						Image(systemName: "plus.square.fill")
					}
				}
				.font(.caption2)
				if !equipment.serialNumber.isEmpty {
					Text("S/N: \(equipment.serialNumber)")
						.font(.caption2)
						.foregroundStyle(.tertiary)
						.lineLimit(1)
				}
			}
		}
#if os(macOS)
		.padding(.vertical, 4)
#endif
		.alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
	}
}

#Preview {
	EquipmentListView()
		.environment(SharedMapState())
		.modelContainer(PreviewContainer.container)
}
