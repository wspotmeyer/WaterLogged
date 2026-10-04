//
//  BulkUpdateView.swift
//  WaterLogged
//
//  Created by John Meyer on 4/23/26.
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

enum ListUpdateMode: String, CaseIterable {
	case replace = "Replace"
	case add = "Add To"
}

/// The per-item action chosen for an individual equipment item or buddy when
/// bulk-updating a dive's list. Presented as a radio-style row of icons.
enum ItemUpdateAction: String, CaseIterable, Identifiable {
	case ignore = "Ignore"
	case add = "Add"
	case delete = "Delete"

	var id: String { rawValue }

	/// The SF Symbol shown for this action. The selected option is rendered
	/// using its `.fill` variant.
	var systemImage: String {
		switch self {
			case .ignore: "circle.slash"
			case .add: "plus.circle"
			case .delete: "trash.circle"
		}
	}

	/// A short description of the action, shown as a hover tooltip.
	var helpText: String {
		switch self {
			case .ignore: "Leave unchanged"
			case .add: "Add to each dive"
			case .delete: "Remove from each dive"
		}
	}

	/// The tint applied when this action is the currently selected option.
	var tint: Color {
		switch self {
			case .ignore: .secondary
			case .add: .green
			case .delete: .red
		}
	}
}

/// A compact radio-style control that lets the user pick a single
/// `ItemUpdateAction` for a list item, showing one icon per option.
private struct ItemActionSelector: View {
	@Binding var action: ItemUpdateAction

	var body: some View {
		HStack(spacing: 16) {
			ForEach(ItemUpdateAction.allCases) { option in
				Button(option.rawValue, systemImage: option.systemImage) {
					action = option
				}
				.labelStyle(.iconOnly)
				.buttonStyle(.plain)
				.symbolVariant(action == option ? .fill : .none)
				.foregroundStyle(action == option ? option.tint : Color.secondary.opacity(0.5))
				.imageScale(.large)
				.help(option.helpText)
				.accessibilityAddTraits(action == option ? [.isSelected] : [])
			}
		}
	}
}

struct BulkUpdateView: View {
	/// How `BulkUpdateView` is being presented. Drives whether it shows a Home
	/// button (embedded in the Tools tab) or a Cancel button (sheet).
	enum Presentation {
		case embedded
		case sheet
	}

	var presentation: Presentation = .embedded

	@Environment(\.dismiss) private var dismiss
	@Environment(\.modelContext) private var modelContext
	@AppStorage("unitSystem") private var unitSystem: UnitSystem = .imperial

	@Query(sort: \Dive.date) private var dives: [Dive]
	@Query(sort: \Equipment.name) private var allEquipment: [Equipment]
	@Query(sort: \Buddy.givenName) private var allBuddies: [Buddy]
	@Query(sort: \DiveSite.name) private var allDiveSites: [DiveSite]

	// MARK: - Dive Range

	@State private var startDive: Dive?
	@State private var endDive: Dive?

	// MARK: - Toggle States

	@State private var updateDiveNumber = false
	@State private var resetSurfaceIntervals = false
	@State private var discardTrivialProfiles = false
	@State private var updateWaterTemp = false
	@State private var updateAirTemp = false
	@State private var updateVisibility = false
	@State private var updateWaterType = false
	@State private var updateCurrent = false
	@State private var updateWaveConditions = false
	@State private var updateWeather = false
	@State private var updateRating = false
	@State private var updateDiveSite = false
	@State private var updateRegion = false
	@State private var updateCountry = false
	@State private var updateDiveGuide = false
	@State private var updateDiveOperator = false
	@State private var updateDiveBoat = false
	@State private var updateTags = false
	@State private var updateSuitType = false
	@State private var updateWeight = false

	// MARK: - Values

	@State private var startingNumber: Int = 1
	@State private var waterTempDisplay: Double?
	@State private var airTempDisplay: Double?
	@State private var visibilityDisplay: Double?
	@State private var waterType: WaterType?
	@State private var current: Current?
	@State private var waveConditions: WaveConditions?
	@State private var weather: String = ""
	@State private var rating: Int = 0
	@State private var selectedDiveSite: DiveSite?
	@State private var region: String = ""
	@State private var country: String = ""
	@State private var diveGuide: String = ""
	@State private var diveOperator: String = ""
	@State private var diveBoat: String = ""
	@State private var tagsText: String = ""
	@State private var selectedSuitType: SuitType?
	@State private var weightDisplay: Double?
	@State private var equipmentActions: [PersistentIdentifier: ItemUpdateAction] = [:]
	@State private var buddyActions: [PersistentIdentifier: ItemUpdateAction] = [:]
	@State private var tagsUpdateMode: ListUpdateMode = .add

	@State private var showingConfirmation = false
	@State private var showingCompletion = false

	// MARK: - Computed

	private var fmt: UnitFormatter { UnitFormatter(system: unitSystem) }

	private var availableEndDives: [Dive] {
		guard let startDive,
			  let startIndex = dives.firstIndex(of: startDive) else { return [] }
		return Array(dives[startIndex...])
	}

	private var divesInRange: [Dive] {
		guard let startDive, let endDive,
			  let startIndex = dives.firstIndex(of: startDive),
			  let endIndex = dives.firstIndex(of: endDive),
			  startIndex <= endIndex else { return [] }
		return Array(dives[startIndex...endIndex])
	}

	/// Equipment offered for bulk updates, excluding retired gear.
	private var selectableEquipment: [Equipment] {
		allEquipment.filter { !$0.isRetired }
	}

	/// Buddies offered for bulk updates, excluding retired buddies.
	private var selectableBuddies: [Buddy] {
		allBuddies.filter { !$0.isRetired }
	}

	/// Whether any equipment item has an action other than `.ignore`.
	private var equipmentActive: Bool {
		equipmentActions.values.contains { $0 != .ignore }
	}

	/// Whether any buddy has an action other than `.ignore`.
	private var buddiesActive: Bool {
		buddyActions.values.contains { $0 != .ignore }
	}

	private var activeUpdateCount: Int {
		[updateDiveNumber, resetSurfaceIntervals, discardTrivialProfiles, updateWaterTemp, updateAirTemp,
		 updateVisibility, updateWaterType, updateCurrent, updateWaveConditions,
		 updateWeather, updateRating, updateDiveSite, updateRegion, updateCountry,
		 updateDiveGuide, updateDiveOperator, updateDiveBoat,
		 updateTags, updateSuitType, updateWeight, equipmentActive, buddiesActive].filter(\.self).count
	}

	private var canApply: Bool {
		startDive != nil && endDive != nil && !divesInRange.isEmpty && activeUpdateCount > 0
	}

	/// A short "N added, M removed" description of a set of per-item actions.
	private func itemActionSummary(_ actions: [PersistentIdentifier: ItemUpdateAction]) -> String {
		let adds = actions.values.filter { $0 == .add }.count
		let deletes = actions.values.filter { $0 == .delete }.count
		var parts: [String] = []
		if adds > 0 { parts.append("\(adds) added") }
		if deletes > 0 { parts.append("\(deletes) removed") }
		return parts.isEmpty ? "no change" : parts.joined(separator: ", ")
	}

	private var confirmationSummary: String {
		var lines: [String] = []
		if updateDiveNumber {
			let count = divesInRange.count
			lines.append("Renumber: #\(startingNumber) – #\(startingNumber + count - 1)")
		}
		if resetSurfaceIntervals { lines.append("Reset Surface Intervals") }
		if discardTrivialProfiles { lines.append("Discard Trivial Depth Profiles") }
		if updateWaterTemp {
			lines.append("Water Temp: \(waterTempDisplay.map { fmt.tempString(fmt.tempToMetric($0)) } ?? "(cleared)")")
		}
		if updateAirTemp {
			lines.append("Air Temp: \(airTempDisplay.map { fmt.tempString(fmt.tempToMetric($0)) } ?? "(cleared)")")
		}
		if updateVisibility {
			lines.append("Visibility: \(visibilityDisplay.map { fmt.visibilityString(fmt.depthToMetric($0)) } ?? "(cleared)")")
		}
		if updateWaterType { lines.append("Water Type: \(waterType?.rawValue ?? "None")") }
		if updateCurrent { lines.append("Current: \(current?.rawValue ?? "None")") }
		if updateWaveConditions { lines.append("Waves: \(waveConditions?.rawValue ?? "None")") }
		if updateWeather { lines.append("Weather: \(weather)") }
		if updateRating {
			lines.append("Rating: \(rating == 0 ? "(cleared)" : "\(rating) star\(rating == 1 ? "" : "s")")")
		}
		if updateDiveSite { lines.append("Dive Site: \(selectedDiveSite?.name ?? "None")") }
		if updateRegion { lines.append("Region: \(region.isEmpty ? "(cleared)" : region)") }
		if updateCountry { lines.append("Country: \(country.isEmpty ? "(cleared)" : country)") }
		if updateDiveGuide { lines.append("Dive Guide: \(diveGuide)") }
		if updateDiveOperator { lines.append("Operator: \(diveOperator)") }
		if updateDiveBoat { lines.append("Boat: \(diveBoat)") }
		if updateTags { lines.append("Tags (\(tagsUpdateMode.rawValue)): \(tagsText.isEmpty ? "(none)" : tagsText)") }
		if updateSuitType { lines.append("Suit: \(selectedSuitType?.rawValue ?? "None")") }
		if updateWeight {
			lines.append("Weight: \(weightDisplay.map { fmt.weightString(fmt.weightToMetric($0)) } ?? "(cleared)")")
		}
		if equipmentActive { lines.append("Equipment: \(itemActionSummary(equipmentActions))") }
		if buddiesActive { lines.append("Buddies: \(itemActionSummary(buddyActions))") }

		let count = divesInRange.count
		let header = "This will update \(count) dive\(count == 1 ? "" : "s"):\n\n"
		let changes = lines.joined(separator: "\n")
		return header + changes + "\n\nThis action cannot be undone."
	}

	// MARK: - Body

	var body: some View {
		NavigationStack {
			Form {
				Group {
					diveRangeSection
					hygieneSection
					conditionsSection
					locationSection
					peopleSection
					equipmentSection
					tagsSection
					summarySection
					applySection
				}
				.tileListRowBackground()
			}
			.formStyle(.grouped)
			.frame(maxWidth: 700)
			.frame(maxWidth: .infinity)
			.appGradientScrollBackground()
			.navigationTitle("Bulk Updater")
#if !os(macOS)
			.navigationBarTitleDisplayMode(.inline)
#endif
			.toolbar {
				if presentation == .sheet {
					ToolbarItem(placement: .cancellationAction) {
						Button("Cancel", systemImage: "xmark") { dismiss() }
					}
				}
			}
			.confirmationDialog(
				"Bulk Update",
				isPresented: $showingConfirmation,
				titleVisibility: .visible
			) {
				Button("Apply Updates", role: .destructive) {
					applyUpdates()
				}
				Button("Cancel", role: .cancel) { }
			} message: {
				Text(confirmationSummary)
			}
			.alert("Updates Applied", isPresented: $showingCompletion) {
				Button("OK") { resetForm() }
			} message: {
				let count = divesInRange.count
				Text("\(count) dive\(count == 1 ? " has" : "s have") been updated successfully.")
			}
		}
	}
}

// MARK: - Sections

private struct DiveRangeSection: View {
	let dives: [Dive]
	let availableEndDives: [Dive]
	@Binding var startDive: Dive?
	@Binding var endDive: Dive?

	var body: some View {
		Section("Dive Range") {
			Picker("Start Dive", selection: $startDive) {
				Text("Select the starting dive").tag(Dive?.none)
				ForEach(dives) { dive in
					DivePickerLabel(dive: dive).tag(Optional(dive))
				}
			}
			.onChange(of: startDive) {
				if let startDive, let endDive,
				   let si = dives.firstIndex(of: startDive),
				   let ei = dives.firstIndex(of: endDive),
				   ei < si {
					self.endDive = nil
				}
			}

			Picker("End Dive", selection: $endDive) {
				Text("Select the ending dive").tag(Dive?.none)
				ForEach(availableEndDives) { dive in
					DivePickerLabel(dive: dive).tag(Optional(dive))
				}
			}
			.disabled(startDive == nil)
		}
	}
}

private struct DivePickerLabel: View {
	let dive: Dive

	var body: some View {
		// Build a plain String first: passing an interpolated literal straight to
		// LocalizedStringKey turns each interpolation into a format argument, and
		// SwiftUI doesn't parse markdown inside format arguments.
		let title = "#\(dive.diveNumber) – \(dive.displayTitle) – \(dive.date.formatted(date: .abbreviated, time: .omitted))"
		Text(LocalizedStringKey(title))
	}
}

private struct ConditionsSection: View {
	let fmt: UnitFormatter
	@Binding var updateWaterTemp: Bool
	@Binding var updateAirTemp: Bool
	@Binding var updateVisibility: Bool
	@Binding var updateWaterType: Bool
	@Binding var updateCurrent: Bool
	@Binding var updateWaveConditions: Bool
	@Binding var updateWeather: Bool
	@Binding var updateRating: Bool
	@Binding var waterTempDisplay: Double?
	@Binding var airTempDisplay: Double?
	@Binding var visibilityDisplay: Double?
	@Binding var waterType: WaterType?
	@Binding var current: Current?
	@Binding var waveConditions: WaveConditions?
	@Binding var weather: String
	@Binding var rating: Int

	var body: some View {
		Section("Conditions and Rating") {
			Toggle("Water Temperature", isOn: $updateWaterTemp)
			if updateWaterTemp {
				LabeledContent(fmt.waterTempFieldLabel) {
					TextField(fmt.waterTempFieldLabel, value: $waterTempDisplay, format: .number, prompt: Text(fmt.tempLabel))
						.labelsHidden()
#if !os(macOS)
						.keyboardType(.decimalPad)
#endif
						.multilineTextAlignment(.trailing)
				}
			}

			Toggle("Air Temperature", isOn: $updateAirTemp)
			if updateAirTemp {
				LabeledContent(fmt.airTempFieldLabel) {
					TextField(fmt.airTempFieldLabel, value: $airTempDisplay, format: .number, prompt: Text(fmt.tempLabel))
						.labelsHidden()
#if !os(macOS)
						.keyboardType(.decimalPad)
#endif
						.multilineTextAlignment(.trailing)
				}
			}

			Toggle("Visibility", isOn: $updateVisibility)
			if updateVisibility {
				LabeledContent(fmt.visibilityFieldLabel) {
					TextField(fmt.visibilityFieldLabel, value: $visibilityDisplay, format: .number, prompt: Text(fmt.depthLabel))
						.labelsHidden()
#if !os(macOS)
						.keyboardType(.decimalPad)
#endif
						.multilineTextAlignment(.trailing)
				}
			}

			Toggle("Water Type", isOn: $updateWaterType)
			if updateWaterType {
				Picker("Water Type", selection: $waterType) {
					Text("None").tag(WaterType?.none)
					ForEach(WaterType.allCases, id: \.self) { w in
						Text(w.rawValue).tag(WaterType?.some(w))
					}
				}
			}

			Toggle("Current", isOn: $updateCurrent)
			if updateCurrent {
				Picker("Current", selection: $current) {
					Text("None").tag(Current?.none)
					ForEach(Current.allCases, id: \.self) { c in
						Text(c.rawValue).tag(Current?.some(c))
					}
				}
			}

			Toggle("Wave Conditions", isOn: $updateWaveConditions)
			if updateWaveConditions {
				Picker("Waves", selection: $waveConditions) {
					Text("None").tag(WaveConditions?.none)
					ForEach(WaveConditions.allCases, id: \.self) { w in
						Text(w.rawValue).tag(WaveConditions?.some(w))
					}
				}
			}

			Toggle("Weather", isOn: $updateWeather)
			if updateWeather {
				LabeledContent("Weather") {
					TextField("Weather", text: $weather, prompt: Text("Weather"))
						.labelsHidden()
						.multilineTextAlignment(.trailing)
				}
			}

			Toggle("Rating", isOn: $updateRating)
			if updateRating {
				LabeledContent("Rating") {
					StarRatingView(rating: rating, interactive: true) { rating = $0 }
				}
			}
		}
	}
}

private struct LocationSection: View {
	let allDiveSites: [DiveSite]
	@Binding var updateDiveSite: Bool
	@Binding var updateRegion: Bool
	@Binding var updateCountry: Bool
	@Binding var selectedDiveSite: DiveSite?
	@Binding var region: String
	@Binding var country: String

	var body: some View {
		Section("Location") {
			Toggle("Dive Site", isOn: $updateDiveSite)
			if updateDiveSite {
				Picker("Dive Site", selection: $selectedDiveSite) {
					Text("None").tag(DiveSite?.none)
					ForEach(allDiveSites) { site in
						Text(site.name.isEmpty ? "(Unnamed)" : site.name).tag(DiveSite?.some(site))
					}
				}
			}

			Toggle("Region", isOn: $updateRegion)
			if updateRegion {
				LabeledContent("Region") {
					TextField("Region", text: $region, prompt: Text("Region"))
						.labelsHidden()
						.multilineTextAlignment(.trailing)
				}
				Text("Updates the region on each dive's site. Dives without a site are skipped unless a site is also being set above.")
					.font(.footnote)
					.foregroundStyle(.secondary)
					.frame(maxWidth: .infinity, alignment: .leading)
			}

			Toggle("Country", isOn: $updateCountry)
			if updateCountry {
				LabeledContent("Country") {
					TextField("Country", text: $country, prompt: Text("Country"))
						.labelsHidden()
						.multilineTextAlignment(.trailing)
				}
				Text("Updates the country on each dive's site. Dives without a site are skipped unless a site is also being set above.")
					.font(.footnote)
					.foregroundStyle(.secondary)
					.frame(maxWidth: .infinity, alignment: .leading)
			}
		}
		.animation(.smooth, value: updateDiveSite)
		.animation(.smooth, value: updateRegion)
		.animation(.smooth, value: updateCountry)
	}
}

private struct PeopleSection: View {
	let allBuddies: [Buddy]
	@Binding var buddyActions: [PersistentIdentifier: ItemUpdateAction]
	@Binding var updateDiveGuide: Bool
	@Binding var updateDiveOperator: Bool
	@Binding var updateDiveBoat: Bool
	@Binding var diveGuide: String
	@Binding var diveOperator: String
	@Binding var diveBoat: String

	var body: some View {
		Section("Buddies") {
			if allBuddies.isEmpty {
				Text("No buddies to update.")
					.foregroundStyle(.secondary)
			} else {
				Text("Choose an action for each buddy.")
					.font(.footnote)
					.foregroundStyle(.secondary)
					.frame(maxWidth: .infinity, alignment: .leading)
				ForEach(allBuddies) { buddy in
					LabeledContent {
						ItemActionSelector(action: buddyBinding(for: buddy))
					} label: {
						HStack {
							BuddyPhoto(photoData: buddy.photoData, size: 24)
							Text(buddy.formattedName)
						}
						.lineLimit(1)
					}
				}
			}
		}

		Section("People") {
			Toggle("Dive Guide", isOn: $updateDiveGuide)
			if updateDiveGuide {
				LabeledContent("Dive Guide") {
					TextField("Dive Guide", text: $diveGuide, prompt: Text("DG"))
						.labelsHidden()
						.multilineTextAlignment(.trailing)
				}
			}

			Toggle("Dive Operator", isOn: $updateDiveOperator)
			if updateDiveOperator {
				LabeledContent("Dive Operator") {
					TextField("Dive Operator", text: $diveOperator, prompt: Text("Operator"))
						.labelsHidden()
						.multilineTextAlignment(.trailing)
				}
			}

			Toggle("Dive Boat", isOn: $updateDiveBoat)
			if updateDiveBoat {
				LabeledContent("Dive Boat") {
					TextField("Dive Boat", text: $diveBoat, prompt: Text("Boat"))
						.labelsHidden()
						.multilineTextAlignment(.trailing)
				}
			}
		}
	}

	private func buddyBinding(for buddy: Buddy) -> Binding<ItemUpdateAction> {
		Binding(
			get: { buddyActions[buddy.id] ?? .ignore },
			set: { buddyActions[buddy.id] = $0 }
		)
	}
}

private struct TagsSection: View {
	@Binding var updateTags: Bool
	@Binding var tagsText: String
	@Binding var tagsUpdateMode: ListUpdateMode

	var body: some View {
		Section("Tags") {
			Toggle("Tags", isOn: $updateTags)
			if updateTags {
				Group {
					VStack {
						Picker("Mode", selection: $tagsUpdateMode) {
							ForEach(ListUpdateMode.allCases, id: \.self) { mode in
								Text(mode.rawValue).tag(mode)
							}
						}
						.pickerStyle(.segmented)
						.labelsHidden()
						.frame(maxWidth: .infinity, alignment: .center)
						Text(tagsUpdateMode == .replace
							 ? "Entered tags will *replace* existing tags on each dive."
							 : "Entered tags will be *added* to each dive's existing tag list.")
						.font(.footnote)
						.foregroundStyle(.secondary)
						.frame(maxWidth: .infinity, alignment: .center)
					}
					LabeledContent("Tags") {
						TextField("Comma-separated", text: $tagsText)
							.multilineTextAlignment(.trailing)
					}
				}
				.padding(.horizontal, 24)
				.alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
			}
		}
		.animation(.smooth, value: updateTags)
	}
}

private struct EquipmentSelectionSection: View {
	let allEquipment: [Equipment]
	@Binding var equipmentActions: [PersistentIdentifier: ItemUpdateAction]

	var body: some View {
		if allEquipment.isEmpty {
			Text("No equipment to update.")
				.foregroundStyle(.secondary)
		} else {
			Text("Choose an action for each equipment item.")
				.font(.footnote)
				.foregroundStyle(.secondary)
				.frame(maxWidth: .infinity, alignment: .leading)
			ForEach(allEquipment) { item in
				LabeledContent {
					ItemActionSelector(action: actionBinding(for: item))
				} label: {
					Text(item.name.isEmpty ? item.resolvedType.label : item.name)
						.lineLimit(1)
				}
			}
		}
	}

	private func actionBinding(for item: Equipment) -> Binding<ItemUpdateAction> {
		Binding(
			get: { equipmentActions[item.id] ?? .ignore },
			set: { equipmentActions[item.id] = $0 }
		)
	}
}

// MARK: - BulkUpdateView Section Properties

extension BulkUpdateView {
	@ViewBuilder var diveRangeSection: some View {
		DiveRangeSection(
			dives: dives,
			availableEndDives: availableEndDives,
			startDive: $startDive,
			endDive: $endDive
		)
	}

	@ViewBuilder var hygieneSection: some View {
		Section("Log Book Hygiene") {
			Toggle("Renumber Dives", isOn: $updateDiveNumber)
			if updateDiveNumber {
				LabeledContent("Starting Number") {
					TextField("Starting Number", value: $startingNumber, format: .number, prompt: Text("start #"))
						.labelsHidden()
#if !os(macOS)
						.keyboardType(.numberPad)
#endif
						.multilineTextAlignment(.trailing)
				}
				if !divesInRange.isEmpty {
					let count = divesInRange.count
					LabeledContent("New number range", value: "\(startingNumber) – \(startingNumber + count - 1)")
				}
				Text("The starting dive in the Dive Range will be given the new number and all dives up to and including the last dive in the range will be renumbered consecutively.")
					.font(.footnote)
					.foregroundStyle(.secondary)
					.frame(maxWidth: .infinity, alignment: .leading)
			}
			Toggle("Reset Surface Intervals", isOn: $resetSurfaceIntervals)
			if resetSurfaceIntervals {
				Text("Explicitly set or imported surface intervals will be cleared and all displayed surface intervals will be calculated automatically.")
					.font(.footnote)
					.foregroundStyle(.secondary)
					.frame(maxWidth: .infinity, alignment: .leading)
			}
			Toggle("Discard Trivial Depth Profiles", isOn: $discardTrivialProfiles)
			if discardTrivialProfiles {
				Text("Depth profiles with fewer than 4 samples will be deleted. These are typically placeholder profiles from UDDF imports.")
					.font(.footnote)
					.foregroundStyle(.secondary)
					.frame(maxWidth: .infinity, alignment: .leading)
			}
		}
	}

	@ViewBuilder var conditionsSection: some View {
		ConditionsSection(
			fmt: fmt,
			updateWaterTemp: $updateWaterTemp,
			updateAirTemp: $updateAirTemp,
			updateVisibility: $updateVisibility,
			updateWaterType: $updateWaterType,
			updateCurrent: $updateCurrent,
			updateWaveConditions: $updateWaveConditions,
			updateWeather: $updateWeather,
			updateRating: $updateRating,
			waterTempDisplay: $waterTempDisplay,
			airTempDisplay: $airTempDisplay,
			visibilityDisplay: $visibilityDisplay,
			waterType: $waterType,
			current: $current,
			waveConditions: $waveConditions,
			weather: $weather,
			rating: $rating
		)
	}

	@ViewBuilder var locationSection: some View {
		LocationSection(
			allDiveSites: allDiveSites,
			updateDiveSite: $updateDiveSite,
			updateRegion: $updateRegion,
			updateCountry: $updateCountry,
			selectedDiveSite: $selectedDiveSite,
			region: $region,
			country: $country
		)
	}

	@ViewBuilder var peopleSection: some View {
		PeopleSection(
			allBuddies: selectableBuddies,
			buddyActions: $buddyActions,
			updateDiveGuide: $updateDiveGuide,
			updateDiveOperator: $updateDiveOperator,
			updateDiveBoat: $updateDiveBoat,
			diveGuide: $diveGuide,
			diveOperator: $diveOperator,
			diveBoat: $diveBoat
		)
	}

	@ViewBuilder var tagsSection: some View {
		TagsSection(updateTags: $updateTags, tagsText: $tagsText, tagsUpdateMode: $tagsUpdateMode)
	}

	@ViewBuilder var equipmentSection: some View {
		Section("Equipment") {
			Toggle("Suit", isOn: $updateSuitType)
			if updateSuitType {
				Picker("Suit", selection: $selectedSuitType) {
					Text("None").tag(SuitType?.none)
					ForEach(SuitType.allCases, id: \.self) { suit in
						Text(suit.rawValue).tag(SuitType?.some(suit))
					}
				}
			}

			Toggle("Weight", isOn: $updateWeight)
			if updateWeight {
				LabeledContent(fmt.weightFieldLabel) {
					TextField(fmt.weightFieldLabel, value: $weightDisplay, format: .number, prompt: Text(fmt.weightLabel))
						.labelsHidden()
#if !os(macOS)
						.keyboardType(.decimalPad)
#endif
						.multilineTextAlignment(.trailing)
				}
			}

			EquipmentSelectionSection(allEquipment: selectableEquipment, equipmentActions: $equipmentActions)
		}
		.animation(.smooth, value: updateSuitType)
		.animation(.smooth, value: updateWeight)
	}

	@ViewBuilder var summarySection: some View {
		if canApply {
			Section("Summary") {
				LabeledContent("Dives to update", value: "\(divesInRange.count)")
				LabeledContent("Properties to change", value: "\(activeUpdateCount)")
			}
		}
	}

	@ViewBuilder var applySection: some View {
		Section {
			Button("Apply Updates", role: .destructive) {
				showingConfirmation = true
			}
			.disabled(!canApply)
		}
	}
}

// MARK: - Apply Logic

extension BulkUpdateView {
	func applyUpdates() {
		let parsedTags = tagsText
			.split(separator: ",")
			.map { $0.trimmingCharacters(in: .whitespaces) }
			.filter { !$0.isEmpty }

		for (offset, dive) in divesInRange.enumerated() {
			if updateDiveNumber { dive.diveNumber = startingNumber + offset }
			if resetSurfaceIntervals { dive.surfaceIntervalSeconds = nil }
			if discardTrivialProfiles, let samples = dive.diveProfile, samples.count < 4 {
				for sample in samples { modelContext.delete(sample) }
				dive.diveProfile = []
			}
			if updateWaterTemp { dive.waterTempCelsius = waterTempDisplay.map(fmt.tempToMetric) }
			if updateAirTemp { dive.airTempCelsius = airTempDisplay.map(fmt.tempToMetric) }
			if updateVisibility { dive.visibilityMeters = visibilityDisplay.map(fmt.depthToMetric) }
			if updateWaterType { dive.waterType = waterType }
			if updateCurrent { dive.current = current }
			if updateWaveConditions { dive.waveConditions = waveConditions }
			if updateWeather { dive.weather = weather }
			if updateRating { dive.rating = rating }
			if updateDiveSite { dive.site = selectedDiveSite }
			if updateRegion, let site = dive.site { site.region = region }
			if updateCountry, let site = dive.site { site.country = country }
			if updateDiveGuide { dive.diveGuide = diveGuide.isEmpty ? nil : diveGuide }
			if updateDiveOperator { dive.diveOperator = diveOperator.isEmpty ? nil : diveOperator }
			if updateDiveBoat { dive.diveBoat = diveBoat.isEmpty ? nil : diveBoat }
			if updateTags {
				if tagsUpdateMode == .add {
					let existing = Set(dive.tags)
					let newTags = parsedTags.filter { !existing.contains($0) }
					dive.tags += newTags
				} else {
					dive.tags = parsedTags
				}
			}
			if updateSuitType { dive.suitType = selectedSuitType }
			if updateWeight { dive.weightKg = weightDisplay.map(fmt.weightToMetric) }
			if equipmentActive {
				dive.equipment = BulkListUpdater.apply(
					to: dive.equipment ?? [],
					from: selectableEquipment,
					actions: equipmentActions
				)
			}
			if buddiesActive {
				dive.buddies = BulkListUpdater.apply(
					to: dive.buddies ?? [],
					from: selectableBuddies,
					actions: buddyActions
				)
			}
		}

		showingCompletion = true
	}

	func resetForm() {
		startDive = nil
		endDive = nil
		updateDiveNumber = false
		resetSurfaceIntervals = false
		discardTrivialProfiles = false
		updateWaterTemp = false
		updateAirTemp = false
		updateVisibility = false
		updateWaterType = false
		updateCurrent = false
		updateWaveConditions = false
		updateWeather = false
		updateRating = false
		updateDiveSite = false
		updateRegion = false
		updateCountry = false
		updateDiveGuide = false
		updateDiveOperator = false
		updateDiveBoat = false
		updateTags = false
		updateSuitType = false
		updateWeight = false
		startingNumber = 1
		waterTempDisplay = nil
		airTempDisplay = nil
		visibilityDisplay = nil
		waterType = nil
		current = nil
		waveConditions = nil
		weather = ""
		rating = 0
		selectedDiveSite = nil
		region = ""
		country = ""
		diveGuide = ""
		diveOperator = ""
		diveBoat = ""
		tagsText = ""
		tagsUpdateMode = .add
		selectedSuitType = nil
		weightDisplay = nil
		equipmentActions = [:]
		buddyActions = [:]
	}
}

#Preview {
	BulkUpdateView()
		.modelContainer(PreviewContainer.container)
}
