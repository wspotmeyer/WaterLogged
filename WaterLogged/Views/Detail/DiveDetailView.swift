//
//  DiveDetailView.swift
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

struct DiveDetailView: View {
	@Environment(\.modelContext) private var modelContext

	let dive: Dive
	var onDelete: (() -> Void)?

	@State private var editingDive: Dive?
	@State private var showingPhotoEditor = false
	@State private var showingLogbookImage = false
	@AppStorage("unitSystem") private var unitSystem: UnitSystem = .imperial
	@AppStorage(PriorDiveHistory.bottomTimeMinutesKey) private var priorBottomTimeMinutes = 0

	private var units: UnitFormatter { UnitFormatter(system: unitSystem) }

	var body: some View {
		if dive.isLive {
			ScrollView {
				VStack(alignment: .leading, spacing: 24) {

					// Header
					VStack(alignment: .leading, spacing: 6) {
						DiveHeaderTitle(dive: dive)
						HStack {
							Text("\(dive.date.formatted(date: .long, time: .omitted)) \(dive.date.formatted(date: .omitted, time: .shortened)) - \(dive.endDate.formatted(date: .omitted, time: .shortened))")
								.font(.subheadline)
								.lineLimit(1)
							Spacer()
							if dive.rating > 0 {
								StarRatingView(rating: dive.rating)
							}
						}
						if let site = dive.site {
							NavigationLink {
								DiveSiteDetailView(site: site)
							} label: {
								HStack(spacing: 12) {
									if !site.name.isEmpty {
										Label(LocalizedStringKey(site.name), systemImage: "mappin.and.ellipse")
											.lineLimit(1)
									}
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
#if !os(macOS)
									Spacer()
#endif
									Image(systemName: "chevron.right")
										.font(.caption)
								}
								.font(.subheadline)
							}
							.buttonStyle(.plain)
						}
						if let trip = dive.trip {
							NavigationLink {
								TripDetailView(trip: trip)
							} label: {
								HStack(spacing: 12) {
									Label(trip.name, systemImage: "airplane.path.dotted")
#if !os(macOS)
									Spacer()
#endif
									Image(systemName: "chevron.right")
										.font(.caption)
								}
								.font(.subheadline)
							}
							.buttonStyle(.plain)
						}
						if let certification = dive.certification {
							NavigationLink {
								CertificationDetailView(certification: certification)
							} label: {
								HStack(spacing: 12) {
									Label(certification.name, systemImage: "graduationcap")
#if !os(macOS)
									Spacer()
#endif
									Image(systemName: "chevron.right")
										.font(.caption)
								}
								.font(.subheadline)
							}
							.buttonStyle(.plain)
						}
					}

					Divider()

					// Key Stats Grid — adapts column count to available width
					// Optional stats use `.map { … } ?? "—"` so every layout always emits
					// a StatCell, keeping the grid shape identical across all ViewThatFits
					// candidates and showing a "—" placeholder when a value is missing.
					ViewThatFits(in: .horizontal) {
						// Single row (wide screens)
						Grid(horizontalSpacing: 12, verticalSpacing: 12) {
							GridRow {
								StatCell(label: "Max Depth", value: units.depthString(dive.maxDepthMeters, decimals: 0), icon: "arrow.down.to.line")
								StatCell(label: "Duration", value: dive.durationFormatted, icon: "clock")
								StatCell(label: "Surface Interval", value: dive.effectiveSurfaceIntervalSeconds == 0 ? "—" : dive.surfaceIntervalFormatted, icon: "water.waves.and.arrow.trianglehead.up")
								StatCell(label: "Water Temp", value: dive.waterTempCelsius.map { units.tempString($0, decimals: 0) } ?? "—", icon: "thermometer.medium")
								StatCell(label: "Visibility", value: dive.visibilityMeters.map { units.visibilityString($0) } ?? "—", icon: "eye")
								StatCell(label: "Current", value: dive.current?.rawValue ?? "—", icon: "wind")
							}
						}

						// Two rows of 3 (medium screens)
						Grid(horizontalSpacing: 12, verticalSpacing: 12) {
							GridRow {
								StatCell(label: "Max Depth", value: units.depthString(dive.maxDepthMeters, decimals: 0), icon: "arrow.down.to.line")
								StatCell(label: "Duration", value: dive.durationFormatted, icon: "clock")
								StatCell(label: "Surface Interval", value: dive.effectiveSurfaceIntervalSeconds == 0 ? "—" : dive.surfaceIntervalFormatted, icon: "water.waves.and.arrow.trianglehead.up")
							}
							GridRow {
								StatCell(label: "Water Temp", value: dive.waterTempCelsius.map { units.tempString($0, decimals: 0) } ?? "—", icon: "thermometer.medium")
								StatCell(label: "Visibility", value: dive.visibilityMeters.map { units.visibilityString($0) } ?? "—", icon: "eye")
								StatCell(label: "Current", value: dive.current?.rawValue ?? "—", icon: "wind")
							}
						}

						// Three rows of 2 (narrow screens)
						Grid(horizontalSpacing: 12, verticalSpacing: 12) {
							GridRow {
								StatCell(label: "Max Depth", value: units.depthString(dive.maxDepthMeters, decimals: 0), icon: "arrow.down.to.line")
								StatCell(label: "Water Temp", value: dive.waterTempCelsius.map { units.tempString($0, decimals: 0) } ?? "—", icon: "thermometer.medium")
							}
							GridRow {
								StatCell(label: "Duration", value: dive.durationFormatted, icon: "clock")
								StatCell(label: "Surface Interval", value: dive.effectiveSurfaceIntervalSeconds == 0 ? "—" : dive.surfaceIntervalFormatted, icon: "water.waves.and.arrow.trianglehead.up")
							}
							GridRow {
								StatCell(label: "Visibility", value: dive.visibilityMeters.map { units.visibilityString($0) } ?? "—", icon: "eye")
								StatCell(label: "Current", value: dive.current?.rawValue ?? "—", icon: "wind")
							}
						}
					}

					HStack {
						Text("Cumulative bottom time: ")
						// Includes bottom time from before the logbook began.
					TimeCount(
						seconds: PriorDiveHistory(bottomTimeMinutes: priorBottomTimeMinutes)
							.totalBottomTimeSeconds(logged: dive.cumulativeDiveTimeSeconds),
						font: .headline
					)
					}

					// Depth Profile (if data available)
					if let diveProfile = dive.diveProfile, !diveProfile.isEmpty {
						// On a tile like the sections below, so the blue depth line, the overlay colors,
						// and the axis labels stay readable against the dark fill instead of the gradient.
						DepthProfileChart(samples: diveProfile, diveStartTime: dive.date)
							.padding()
							.tileBackground()
					}

					// Detail Sections — adapts column count to available width
					ViewThatFits(in: .horizontal) {
						// Three-column layout (wide screens)
						HStack(alignment: .top, spacing: 12) {
							DetailColumn {
								ConditionsSectionView(dive: dive, units: units)
							}
							DetailColumn {
								ProtectionGasView(dive: dive, units: units)
								GearSectionView(dive: dive)
							}
							DetailColumn {
								BuddiesSectionView(dive: dive)
								PeopleSectionView(dive: dive)
							}
						}

						// Two-column layout
						HStack(alignment: .top, spacing: 12) {
							DetailColumn {
								ConditionsSectionView(dive: dive, units: units)
								BuddiesSectionView(dive: dive)
								PeopleSectionView(dive: dive)
							}
							DetailColumn {
								ProtectionGasView(dive: dive, units: units)
								GearSectionView(dive: dive)
							}
						}

						// Single-column layout (narrowest)
						VStack(alignment: .leading, spacing: 12) {
							ConditionsSectionView(dive: dive, units: units)
							ProtectionGasView(dive: dive, units: units)
							GearSectionView(dive: dive)
							BuddiesSectionView(dive: dive)
							PeopleSectionView(dive: dive)
						}
					}

					// Notes & Map — side by side on wide screens only
					ViewThatFits(in: .horizontal) {
						HStack(alignment: .top, spacing: 12) {
							DetailColumn {
								if let site = dive.site {
									DiveSiteMapView(
										diveSite: site,
										startLatitude: dive.startLatitude,
										startLongitude: dive.startLongitude,
										endLatitude: dive.endLatitude,
										endLongitude: dive.endLongitude
									)
									.id(site.persistentModelID)
								}
							}
							.frame(idealWidth: 400, maxWidth: .infinity, alignment: .leading)
							DetailColumn {
								NotesSectionView(dive: dive)
								TagsSectionView(dive: dive)
							}
							.frame(idealWidth: 400, maxWidth: .infinity, alignment: .leading)
						}

						VStack(alignment: .leading, spacing: 12) {
							if let site = dive.site {
								DiveSiteMapView(
									diveSite: site,
									startLatitude: dive.startLatitude,
									startLongitude: dive.startLongitude,
									endLatitude: dive.endLatitude,
									endLongitude: dive.endLongitude
								)
								.id(site.persistentModelID)
							}
							NotesSectionView(dive: dive)
							TagsSectionView(dive: dive)
						}
					}

					VStack(alignment: .leading, spacing: 10) {
						HStack {
							Text("Photos")
								.font(.title2.bold())
							Spacer()
							Button("Edit Photos", systemImage: "pencil") {
								showingPhotoEditor = true
							}
							.labelStyle(.iconOnly)
						}
						if let photos = dive.photos, !photos.isEmpty {
							PhotoCarouselView(photos: photos)
						} else {
							// Normally, any missing data (notes, etc.) are simply not displayed. Here,
							// we use a "no photos yet" message because we want to direct the user to
							// the edit (pencil) icon on the label line. It is unique to the photos and
							// is used nowhere else.
							Text("No photos yet.")
						}
					}

					if dive.logbookImageData != nil || dive.verificationSignatureData != nil {
						ViewThatFits(in: .horizontal) {
							HStack(alignment: .top, spacing: 12) {
								if dive.logbookImageData != nil {
									DetailColumn {
										LogbookThumbnailView(dive: dive, showingLogbookImage: $showingLogbookImage)
									}
									.frame(idealWidth: 400, maxWidth: .infinity, alignment: .leading)
								}
								if dive.verificationSignatureData != nil {
									DetailColumn {
										SignatureSectionView(dive: dive)
									}
									.frame(idealWidth: 400, maxWidth: .infinity, alignment: .leading)
								}
							}

							VStack(alignment: .leading, spacing: 12) {
								if dive.logbookImageData != nil {
									LogbookThumbnailView(dive: dive, showingLogbookImage: $showingLogbookImage)
								}
								if dive.verificationSignatureData != nil {
									SignatureSectionView(dive: dive)
								}
							}
						}
					}

					ImportSourceFooterView(dive: dive)
				}
				.padding()
			}
			.appGradientScrollBackground()
#if os(macOS)
			.sheet(isPresented: $showingLogbookImage) {
				LogbookImageViewer(dive: dive)
			}
#else
			.fullScreenCover(isPresented: $showingLogbookImage) {
				LogbookImageViewer(dive: dive)
			}
#endif
			.toolbar {
				ToolbarItem(placement: .primaryAction) {
					Button("Edit", systemImage: "pencil") { editingDive = dive }
				}
			}
			.sheet(item: $editingDive) { editing in
				DiveEntryView(dive: editing) {
					modelContext.delete(editing)
					onDelete?()
				}
			}
			.sheet(isPresented: $showingPhotoEditor) {
				PhotoEditSheet(existingPhotos: dive.photos ?? []) { entries in
					Photo.replace(dive.photos, with: entries, in: modelContext) { $0.dive = dive }
				}
			}
		}
	}
}

// MARK: - Detail Section Views

/// The dive number and title at the top of the detail view.
///
/// At accessibility text sizes the badge is stacked above the title, since it grows too wide at
/// those sizes to leave the title room on one line.
private struct DiveHeaderTitle: View {
	let dive: Dive

	@Environment(\.dynamicTypeSize) private var dynamicTypeSize

	var body: some View {
		if dynamicTypeSize.isAccessibilitySize {
			VStack(alignment: .leading, spacing: 6) {
				DiveNumberBadge(diveNumber: dive.diveNumber, textStyle: .title)
				Text(LocalizedStringKey(dive.displayTitle))
					.font(.title.bold())
			}
		} else {
			HStack {
				DiveNumberBadge(diveNumber: dive.diveNumber, textStyle: .title)
				Text(LocalizedStringKey(dive.displayTitle))
					.font(.title.bold())
					.lineLimit(1)
			}
		}
	}
}

private struct ConditionsSectionView: View {
	let dive: Dive
	let units: UnitFormatter

	var body: some View {
		DetailSection(title: "Conditions") {
			if let waterTemp = dive.waterTempCelsius {
				DetailRow(label: "Water Temp", value: units.tempString(waterTemp, decimals: 0))
			}
			if let airTemp = dive.airTempCelsius {
				DetailRow(label: "Air Temp", value: units.tempString(airTemp, decimals: 0))
			}
			DetailRow(label: "Visibility", value: dive.visibilityMeters.map { units.visibilityString($0) } ?? "—")
			DetailRow(label: "Current", value: dive.current?.rawValue ?? "—")
			DetailRow(label: "Water Type", value: dive.waterType?.rawValue ?? "—")
			DetailRow(label: "Waves", value: dive.waveConditions?.rawValue ?? "—")
			if !dive.weather.isEmpty {
				DetailRow(label: "Weather", value: dive.weather)
			}
		}
	}
}

private struct ProtectionGasView: View {
	let dive: Dive
	let units: UnitFormatter

	private var tanks: [Tank] {
		dive.tanks ?? []
	}

	var body: some View {
		DetailSection(title: "Protection & Gas") {
			if let suitType = dive.suitType {
				DetailRow(label: "Suit", value: suitType.rawValue)
			}
			if let weightKg = dive.weightKg {
				DetailRow(label: "Weight", value: units.weightString(weightKg))
			}

			if !tanks.isEmpty {
				ForEach(tanks.enumerated(), id: \.element.id) { index, tank in
					TankRowView(tank: tank, index: index, units: units)
					if index < tanks.count - 1 {
						Divider()
					}
				}
			}
		}
	}
}

private struct TankRowView: View {
	let tank: Tank
	let index: Int
	let units: UnitFormatter

	private var tankLabel: String {
		if let name = tank.equipment?.name, !name.isEmpty {
			return name
		}
		return "Tank \(index + 1)"
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 6) {
			// Tank name on the leading edge, with the gas it held opposite it.
			HStack {
				if let equipment = tank.equipment {
					NavigationLink {
						EquipmentDetailView(equipment: equipment)
					} label: {
						HStack {
							Text(tankLabel)
								.fontWeight(.semibold)
							Image(systemName: "chevron.right")
								.font(.caption)
						}
					}
					.buttonStyle(.plain)
				} else {
					Text(tankLabel)
						.fontWeight(.semibold)
				}
				Spacer()
				if let gas = tank.gasMix {
					NavigationLink {
						GasMixDetailView(gasMix: gas)
					} label: {
						HStack {
							Text(gas.displayName)
								.fontWeight(.medium)
							Image(systemName: "chevron.right")
								.font(.caption)
						}
					}
					.buttonStyle(.plain)
				}
			}
			.font(.subheadline)

			// Gas make-up on the leading edge, with the tank's pressures opposite it.
			HStack(alignment: .top) {
				if let gas = tank.gasMix {
					TankGasComponents(gasMix: gas)
				}
				Spacer()
				// A grid keeps the icons in one column and the readings right-justified in another.
				Grid(alignment: .trailing) {
					if let startPressure = tank.startPressureBar {
						GridRow {
							TankPressureIcon(isFull: true)
							Text(units.pressureString(startPressure))
								.fontWeight(.medium)
								.accessibilityLabel("Start pressure")
								.accessibilityValue(units.pressureString(startPressure))
						}
					}
					if let endPressure = tank.endPressureBar {
						GridRow {
							TankPressureIcon(isFull: false)
							Text(units.pressureString(endPressure))
								.fontWeight(.medium)
								.accessibilityLabel("End pressure")
								.accessibilityValue(units.pressureString(endPressure))
						}
					}
				}
			}
			.font(.subheadline)
		}
	}
}

/// The gas make-up of a tank, one component per line.
private struct TankGasComponents: View {
	let gasMix: GasMix

	var body: some View {
		VStack(alignment: .leading) {
			ForEach(gasMix.components) { component in
				HStack {
					Text(component.symbol)
					Text(component.fraction, format: .percent.precision(.fractionLength(0)))
				}
			}
		}
	}
}

/// A scuba tank icon laid on its side, full for a start pressure and empty for an end pressure.
private struct TankPressureIcon: View {
	let isFull: Bool

	@ScaledMetric(relativeTo: .subheadline) private var iconLength: CGFloat = 32

	/// The artwork is drawn upright, so its width is a fraction of its height.
	private var iconThickness: CGFloat {
		iconLength * 32.8 / 93.6
	}

	var body: some View {
		Image(isFull ? .scubaTankFull : .scubaTankLow)
			.renderingMode(.template)
			.resizable()
			.scaledToFit()
			.frame(width: iconThickness, height: iconLength)
			.rotationEffect(.degrees(-90))
			// A rotation effect doesn't change the layout frame, so claim the rotated bounds.
			.frame(width: iconLength, height: iconThickness)
			.accessibilityHidden(true)
	}
}

private struct GearSectionView: View {
	let dive: Dive

	@State private var isExpanded = false

	/// Relationship arrays have no guaranteed order, so sort to keep the icon stack stable between launches.
	private var equipment: [Equipment] {
		(dive.equipment ?? []).sorted {
			$0.name.localizedStandardCompare($1.name) == .orderedAscending
		}
	}

	var body: some View {
		if !equipment.isEmpty {
			DetailSection(title: "Gear") {
				VStack(alignment: .leading) {
					GearSummaryRow(equipment: equipment, isExpanded: $isExpanded)
					if isExpanded {
						ForEach(equipment) { item in
							GearLinkRow(equipment: item)
						}
					}
				}
			}
		}
	}
}

/// Collapsed summary of a dive's gear: overlapping type icons, a count of the ones that don't fit,
/// and a control that reveals or hides the full list.
private struct GearSummaryRow: View {
	let equipment: [Equipment]
	@Binding var isExpanded: Bool

	private var hiddenCount: Int {
		max(equipment.count - GearIconStack.maximumVisible, 0)
	}

	var body: some View {
		HStack {
			GearIconStack(equipment: equipment)
			if hiddenCount > 0, !isExpanded {
				Text("+\(hiddenCount)")
					.font(.subheadline)
					.monospacedDigit()
			}
			Spacer()
			DisclosureToggleButton(isExpanded: $isExpanded, subject: "Gear")
		}
	}
}

/// Overlapping circular type icons for the first few pieces of gear on a dive.
private struct GearIconStack: View {
	static let maximumVisible = 9

	let equipment: [Equipment]

	@ScaledMetric(relativeTo: .body) private var badgeSize: CGFloat = 28

	var body: some View {
		// Later badges draw on top of the ones they overlap, following the HStack's natural order.
		// The overlap is shallower than the buddy avatars' because a partly covered glyph stops
		// being recognizable, so it only eats into the circle's padding.
		HStack(spacing: -badgeSize / 6) {
			ForEach(equipment.prefix(Self.maximumVisible)) { item in
				EquipmentTypeIcon(type: item.resolvedType, announcesType: false)
					.frame(width: badgeSize, height: badgeSize)
					.background(.quaternary, in: .circle)
					.overlay {
						Circle()
							.strokeBorder(.background, lineWidth: 2)
					}
			}
		}
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(equipment.map(\.name).formatted(.list(type: .and)))
	}
}

private struct GearLinkRow: View {
	let equipment: Equipment

	var body: some View {
		NavigationLink {
			EquipmentDetailView(equipment: equipment)
		} label: {
			HStack {
				// A fixed icon column keeps the gear names aligned down the list.
				EquipmentTypeIcon(type: equipment.resolvedType)
					.frame(width: 24)
				Text(equipment.name)
					.font(.subheadline)
					.fontWeight(.medium)
				Spacer()
				if !equipment.manufacturer.isEmpty {
					Text(equipment.manufacturer)
						.font(.subheadline)
						.foregroundStyle(.secondary)
				}
				Image(systemName: "chevron.right")
					.font(.caption)
			}
		}
		.buttonStyle(.plain)
	}
}

private struct BuddiesSectionView: View {
	let dive: Dive

	@State private var isExpanded = false

	/// Relationship arrays have no guaranteed order, so sort to keep the avatar stack stable between launches.
	private var buddies: [Buddy] {
		(dive.buddies ?? []).sorted {
			$0.formattedName.localizedStandardCompare($1.formattedName) == .orderedAscending
		}
	}

	var body: some View {
		if !buddies.isEmpty {
			DetailSection(title: "Buddies") {
				VStack(alignment: .leading) {
					BuddySummaryRow(buddies: buddies, isExpanded: $isExpanded)
					if isExpanded {
						ForEach(buddies) { buddy in
							BuddyLinkRow(buddy: buddy)
						}
					}
				}
			}
		}
	}
}

/// Collapsed summary of a dive's buddies: overlapping avatars, a count of the ones that don't fit,
/// and a control that reveals or hides the full list.
private struct BuddySummaryRow: View {
	let buddies: [Buddy]
	@Binding var isExpanded: Bool

	private var hiddenCount: Int {
		max(buddies.count - BuddyAvatarStack.maximumVisible, 0)
	}

	var body: some View {
		HStack {
			BuddyAvatarStack(buddies: buddies)
			if hiddenCount > 0, !isExpanded {
				Text("+\(hiddenCount)")
					.font(.subheadline)
					.monospacedDigit()
			}
			Spacer()
			DisclosureToggleButton(isExpanded: $isExpanded, subject: "Buddies")
		}
	}
}

/// Overlapping circular avatars for the first few buddies of a dive.
private struct BuddyAvatarStack: View {
	static let maximumVisible = 9

	let buddies: [Buddy]

	private let avatarSize: CGFloat = 28

	var body: some View {
		// Later avatars draw on top of the ones they overlap, following the HStack's natural order.
		HStack(spacing: -avatarSize / 3) {
			ForEach(buddies.prefix(Self.maximumVisible)) { buddy in
				BuddyPhoto(photoData: buddy.photoData, size: avatarSize)
					.background(.background, in: .circle)
					.overlay {
						Circle()
							.strokeBorder(.background, lineWidth: 2)
					}
			}
		}
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(buddies.map(\.formattedName).formatted(.list(type: .and)))
	}
}

private struct BuddyLinkRow: View {
	let buddy: Buddy

	var body: some View {
		NavigationLink {
			BuddyDetailView(buddy: buddy)
		} label: {
			HStack {
				BuddyPhoto(photoData: buddy.photoData, size: 24)
				Text(buddy.formattedName)
					.font(.subheadline)
					.fontWeight(.medium)
				Spacer()
				Image(systemName: "chevron.right")
					.font(.caption)
			}
		}
		.buttonStyle(.plain)
	}
}

private struct PeopleSectionView: View {
	let dive: Dive

	var body: some View {
		if dive.diveGuide != nil || dive.diveOperator != nil || dive.diveBoat != nil {
			DetailSection(title: "Operator") {
				if let diveGuide = dive.diveGuide, !diveGuide.isEmpty { DetailRow(label: "Dive Guide", value: diveGuide) }
				if let diveOperator = dive.diveOperator, !diveOperator.isEmpty { DetailRow(label: "Dive Operator", value: diveOperator) }
				if let diveBoat = dive.diveBoat, !diveBoat.isEmpty { DetailRow(label: "Dive Boat", value: diveBoat) }
			}
		}
	}
}

private struct NotesSectionView: View {
	let dive: Dive

	var body: some View {
		if !dive.notes.isEmpty {
			VStack(alignment: .leading, spacing: 10) {
				DetailSection(title: "Notes") {
					Text(LocalizedStringKey(dive.notes))
						.foregroundStyle(.secondary)
				}
			}
		}
	}
}

/// Where this dive's record came from, shown as a footnote at the very bottom
/// of the detail view. A dive computer import records the model name, so this
/// is how a diver tells a downloaded dive from a hand-entered or imported one.
private struct ImportSourceFooterView: View {
	let dive: Dive

	var body: some View {
		let source = dive.importSource.trimmingCharacters(in: .whitespaces)
		if !source.isEmpty {
			Divider()
			Group {
				switch source {
					case "Manual":
						Text("Added manually")
					case "UDDF":
						Text("Imported from a UDDF file")
					default:
						Text("Imported from \(source)")
				}
			}
			.font(.footnote)
			.foregroundStyle(.secondary)
			.frame(maxWidth: .infinity, alignment: .leading)
		}
	}
}

private struct TagsSectionView: View {
	let dive: Dive

	var body: some View {
		if !dive.tags.isEmpty {
			VStack(alignment: .leading, spacing: 10) {
				Text("Tags")
					.font(.title2.bold())
				TagsListView(tags: dive.tags)
			}
		}
	}
}

// MARK: - Helper Views

private struct LogbookThumbnailView: View {
	let dive: Dive
	@Binding var showingLogbookImage: Bool

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			Text("Log Book Page")
				.font(.title2.bold())
			if let data = dive.logbookImageData, let image = makeDisplayImage(from: data) {
				Button {
					showingLogbookImage = true
				} label: {
					image
						.resizable()
						.scaledToFit()
						.frame(maxHeight: 200)
						.clipShape(.rect(cornerRadius: 8))
				}
				.buttonStyle(.plain)
			}
		}
	}
}

private struct LogbookImageViewer: View {
	@Environment(\.dismiss) private var dismiss
	let dive: Dive

	var body: some View {
		NavigationStack {
			Group {
				if let data = dive.logbookImageData, let image = makeDisplayImage(from: data) {
					image
						.resizable()
						.scaledToFit()
				} else {
					ContentUnavailableView("No Image", systemImage: "photo")
				}
			}
			.navigationTitle("Log Book Page")
#if os(macOS)
			.presentationSizing(.fitted)
#endif
#if !os(macOS)
			.navigationBarTitleDisplayMode(.inline)
#endif
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Done", systemImage: "xmark") { dismiss() }
				}
				if let data = dive.logbookImageData, let image = makeDisplayImage(from: data) {
					ToolbarItem(placement: .primaryAction) {
						ShareLink(
							item: ImageFileHelper.shareableFile(
								data: data,
								filename: dive.logbookImageFilename
							),
							preview: SharePreview("Log Book Page", image: image)
						)
					}
				}
			}
		}
	}
}

private struct SignatureSectionView: View {
	let dive: Dive

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			Text("Verification Signature")
				.font(.title2.bold())
			if let data = dive.verificationSignatureData, let image = makeDisplayImage(from: data) {
				image
					.renderingMode(.template)
					.resizable()
					.scaledToFit()
					.foregroundStyle(.primary)
					.frame(maxHeight: 150)
					.clipShape(.rect(cornerRadius: 8))
			}
		}
	}
}

#Preview {
	let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
	// swiftlint:disable force_try
	let container = try! ModelContainer(
		for: Dive.self, GasMix.self, DiveSite.self, DepthSample.self, Equipment.self, ServiceRecord.self, Certification.self, Buddy.self, Trip.self, Photo.self, Tank.self,
		configurations: config
	)
	PreviewContainer.insertSampleData(into: container)
	let dive = try! container.mainContext.fetch(FetchDescriptor<Dive>()).first!
	// swiftlint:enable force_try
	return NavigationStack {
		DiveDetailView(dive: dive)
	}
	.modelContainer(container)
}

#Preview("Import Source Footer") {
	VStack(alignment: .leading, spacing: 16) {
		ImportSourceFooterView(dive: Dive(importSource: "Oceanic Pro Plus X"))
		ImportSourceFooterView(dive: Dive(importSource: "UDDF"))
		ImportSourceFooterView(dive: Dive(importSource: "Manual"))
		ImportSourceFooterView(dive: Dive(importSource: ""))
	}
	.padding()
}
