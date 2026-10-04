//
//  DiveEntryView.swift
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
import PhotosUI
#if !os(macOS)
import PencilKit
#endif
import UniformTypeIdentifiers

struct DiveEntryView: View {
	@Environment(\.modelContext) private var modelContext
	@Environment(\.dismiss) private var dismiss
	@AppStorage("unitSystem") private var unitSystem: UnitSystem = .imperial

	private var units: UnitFormatter { UnitFormatter(system: unitSystem) }

	@Query(sort: \DiveSite.name) private var availableSites: [DiveSite]
	@Query(sort: \Trip.startDate, order: .reverse) private var availableTrips: [Trip]
	@Query(sort: \Certification.name) private var availableCertifications: [Certification]

	// Pass nil to create, pass a Dive to edit
	let dive: Dive?
	var onDelete: (() -> Void)?

	// MARK: - Form State
	@State private var diveNumber: Int = 0
	@State private var title: String = ""
	@State private var date: Date = .now
	@State private var selectedSite: DiveSite?
	@State private var maxDepth: Double = 0
	@State private var durationMinutes: Int = 0
	@State private var durationSeconds: Int = 0
	@State private var surfaceIntervalHours: Int = 0
	@State private var surfaceIntervalMinutes: Int = 0
	@State private var surfaceIntervalSeconds: Int = 0
	@State private var waterTemp: String = ""
	@State private var airTemp: String = ""
	@State private var visibilityText: String = ""
	@State private var waterType: WaterType?
	@State private var current: Current?
	@State private var waves: WaveConditions?
	@State private var weather: String = ""
	@State private var suitType: SuitType?
	@State private var weight: Double = 0
	@State private var diveGuide: String = ""
	@State private var diveOperator: String = ""
	@State private var diveBoat: String = ""
	@State private var rating: Int = 0
	@State private var notes: String = ""
	@State private var tags: String = ""  // comma-separated input

	@State private var selectedTrip: Trip?
	@State private var selectedCertification: Certification?
	@State private var startLatitudeText: String = ""
	@State private var startLongitudeText: String = ""
	@State private var endLatitudeText: String = ""
	@State private var endLongitudeText: String = ""

	@State private var showingNewSite = false
	@State private var showingNewGasMix = false

	// Gas & Tanks
	@Query(sort: \GasMix.name) private var availableGasMixes: [GasMix]
	@State private var tankEntries: [TankEntry] = []

	// Equipment
	@Query(sort: \Equipment.name) private var allEquipment: [Equipment]
	@State private var selectedEquipment: Set<PersistentIdentifier> = []
	@State private var hasLoadedAutoAdd = false

	// Buddies
	@Query(sort: [SortDescriptor(\Buddy.familyName), SortDescriptor(\Buddy.givenName)]) private var allBuddies: [Buddy]
	@State private var selectedBuddies: Set<PersistentIdentifier> = []

	// Logbook image
	@State private var logbookImageData: Data?
	@State private var logbookImageFilename = ""
	@State private var logbookPhotoItem: PhotosPickerItem?

	// Verification signature
#if !os(macOS)
	@State private var signatureDrawing = PKDrawing()
#endif
	@State private var verificationSignatureData: Data?

	@State private var showingLogbookFileImporter = false

	private static let allowedImageTypes: [UTType] = [.jpeg, .png, .gif, .tiff]

	@State private var showingDeleteConfirmation = false

	var isEditing: Bool { dive != nil }

	var body: some View {
		NavigationStack {
			Form {
				Group {
					BasicInformationSection(
						diveNumber: $diveNumber,
						title: $title,
						date: $date
					)
					LocationSection(
						selectedSite: $selectedSite,
						availableSites: availableSites,
						showingNewSite: $showingNewSite,
						startLatitudeText: $startLatitudeText,
						startLongitudeText: $startLongitudeText,
						endLatitudeText: $endLatitudeText,
						endLongitudeText: $endLongitudeText
					)
					TripSelectionSection(
						selectedTrip: $selectedTrip,
						availableTrips: availableTrips
					)
					CertificationSelectionSection(
						selectedCertification: $selectedCertification,
						availableCertifications: availableCertifications
					)
					DepthTimeSection(
						maxDepth: $maxDepth,
						durationMinutes: $durationMinutes,
						durationSeconds: $durationSeconds,
						surfaceIntervalHours: $surfaceIntervalHours,
						surfaceIntervalMinutes: $surfaceIntervalMinutes,
						surfaceIntervalSeconds: $surfaceIntervalSeconds,
						units: units
					)
					ConditionsSection(
						waterTemp: $waterTemp,
						airTemp: $airTemp,
						visibilityText: $visibilityText,
						waterType: $waterType,
						current: $current,
						waves: $waves,
						weather: $weather,
						units: units
					)
					GearSection(
						suitType: $suitType,
						weight: $weight,
						units: units
					)
					TanksSection(
						tankEntries: $tankEntries,
						availableGasMixes: availableGasMixes,
						availableTanks: allEquipment.filter { $0.resolvedType == .tank && !$0.isRetired },
						showingNewGasMix: $showingNewGasMix,
						units: units
					)
					EquipmentSelectionSection(
						allEquipment: allEquipment,
						selectedEquipment: $selectedEquipment
					)
					BuddySelectionSection(
						allBuddies: allBuddies,
						selectedBuddies: $selectedBuddies
					)
					PeopleSection(
						diveGuide: $diveGuide,
						diveOperator: $diveOperator,
						diveBoat: $diveBoat
					)
					LogbookImageSection(
						imageData: $logbookImageData,
						photoItem: $logbookPhotoItem,
						showingFileImporter: $showingLogbookFileImporter
					)
					RatingNotesSection(
						rating: $rating,
						notes: $notes,
						tags: $tags
					)
#if !os(macOS)
					VerificationSignatureSection(
						signatureData: $verificationSignatureData,
						drawing: $signatureDrawing
					)
#else
					// macOS has no signature canvas, but a signature can arrive via
					// UDDF import or backup restore — show it so it can be cleared.
					if verificationSignatureData != nil {
						VerificationSignatureSection(signatureData: $verificationSignatureData)
					}
#endif
					if isEditing {
						Section {
							Button("Delete This Dive", role: .destructive) {
								showingDeleteConfirmation = true
							}
						}
					}
				}
				.tileListRowBackground()
			}
			.formStyle(.grouped)
			.appGradientScrollBackground()
			.navigationTitle(isEditing ? "Edit Dive" : "Log Dive")
#if os(iOS)
			.navigationBarTitleDisplayMode(.inline)
#endif
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel", systemImage: "xmark") { dismiss() }
				}
				ToolbarItem(placement: .confirmationAction) {
					Button("Save", systemImage: "checkmark") { save() }
						.buttonStyle(.borderedProminent)
				}
			}
			.onAppear {
				populateIfEditing()
				preselectAutoAddEquipment()
			}
			.sheet(isPresented: $showingNewSite) {
				DiveSiteEntryView(site: nil, onSave: { newSite in
					selectedSite = newSite
				})
			}
			.sheet(isPresented: $showingNewGasMix) {
				GasMixEntryView(gasMix: nil, onSave: { _ in })
			}
			.onChange(of: logbookPhotoItem) { _, newItem in
				Task {
					let data = await loadImageData(from: newItem)
					logbookImageData = data
					if let data {
						logbookImageFilename = ImageFileHelper.defaultFilename(for: data)
					}
				}
			}
			.fileImporter(
				isPresented: $showingLogbookFileImporter,
				allowedContentTypes: Self.allowedImageTypes,
				allowsMultipleSelection: false
			) { (result: Result<[URL], any Error>) in
				guard let url = try? result.get().first else { return }
				guard url.startAccessingSecurityScopedResource() else { return }
				defer { url.stopAccessingSecurityScopedResource() }
				logbookImageData = try? Data(contentsOf: url)
				logbookImageFilename = url.lastPathComponent
			}
			.alert("Delete This Dive?", isPresented: $showingDeleteConfirmation) {
				Button("Delete", role: .destructive) {
					dismiss()
					onDelete?()
				}
				Button("Cancel", role: .cancel) { }
			} message: {
				Text("Are you sure you want to delete this dive? This cannot be undone.")
			}
		}
#if os(macOS)
		.frame(minWidth: 500, idealWidth: 650, minHeight: 500, idealHeight: 700)
#endif
	}

	// MARK: - Logic

	private func populateIfEditing() {
		guard let d = dive else { return }
		diveNumber = d.diveNumber
		title = d.title
		date = d.date
		maxDepth = units.depthForDisplay(d.maxDepthMeters)
		durationMinutes = d.durationSeconds / 60
		durationSeconds = d.durationSeconds % 60
		if let si = d.surfaceIntervalSeconds {
			surfaceIntervalHours = si / 3600
			surfaceIntervalMinutes = (si % 3600) / 60
			surfaceIntervalSeconds = si % 60
		}
		waterTemp = d.waterTempCelsius.map { "\(Int(units.tempForDisplay($0).rounded()))" } ?? ""
		airTemp = d.airTempCelsius.map { "\(Int(units.tempForDisplay($0).rounded()))" } ?? ""
		visibilityText = d.visibilityMeters.map { "\(Int(units.depthForDisplay($0).rounded()))" } ?? ""
		waterType = d.waterType
		current = d.current
		waves = d.waveConditions
		weather = d.weather
		suitType = d.suitType
		weight = d.weightKg.map { units.weightForDisplay($0) } ?? 0
		diveGuide = d.diveGuide ?? ""
		diveOperator = d.diveOperator ?? ""
		diveBoat = d.diveBoat ?? ""
		rating = d.rating
		notes = d.notes
		startLatitudeText = d.startLatitude.map { "\($0)" } ?? ""
		startLongitudeText = d.startLongitude.map { "\($0)" } ?? ""
		endLatitudeText = d.endLatitude.map { "\($0)" } ?? ""
		endLongitudeText = d.endLongitude.map { "\($0)" } ?? ""
		selectedSite = d.site
		selectedTrip = d.trip
		selectedCertification = d.certification
		tags = d.tags.joined(separator: ", ")
		if let tanks = d.tanks {
			tankEntries = tanks.map { TankEntry(from: $0, units: units) }
		}
		if let equipment = d.equipment {
			selectedEquipment = Set(equipment.map(\.persistentModelID))
		}
		if let buddies = d.buddies {
			selectedBuddies = Set(buddies.map(\.persistentModelID))
		}
		logbookImageData = d.logbookImageData
		logbookImageFilename = d.logbookImageFilename
		verificationSignatureData = d.verificationSignatureData
	}

	/// Ticks the equipment marked "Auto-add to New Dives" when logging a new dive.
	///
	/// Only for new dives: an existing dive already records the gear it was logged with, so applying
	/// the flag while editing would silently add equipment the diver never wore. Guarded by
	/// `hasLoadedAutoAdd` so it runs once per presentation — `onAppear` can fire again for the same
	/// form, and re-applying would re-tick rows the diver had just turned off.
	private func preselectAutoAddEquipment() {
		guard !isEditing, !hasLoadedAutoAdd else { return }
		hasLoadedAutoAdd = true
		selectedEquipment.formUnion(EquipmentAutoAdd.preselection(from: allEquipment))
	}

	// MARK: - Image Loading

	private func loadImageData(from item: PhotosPickerItem?) async -> Data? {
		guard let item else { return nil }
		return try? await item.loadTransferable(type: Data.self)
	}

	private func saveTanks(to dive: Dive) {
		if let existing = dive.tanks {
			for tank in existing {
				modelContext.delete(tank)
			}
		}
		for entry in tankEntries {
			let tank = Tank(
				externalId: entry.externalId,
				equipment: entry.equipment,
				gasMix: entry.gasMix,
				startPressureBar: entry.startPressureDisplay.map { units.pressureToMetric($0) },
				endPressureBar: entry.endPressureDisplay.map { units.pressureToMetric($0) }
			)
			tank.dive = dive
			modelContext.insert(tank)
		}
	}

#if !os(macOS)
	private func renderSignatureToImageData(_ drawing: PKDrawing) -> Data? {
		guard !drawing.strokes.isEmpty else { return nil }
		let bounds = drawing.bounds.insetBy(dx: -10, dy: -10)
		let image = drawing.image(from: bounds, scale: 2.0)
		return image.pngData()
	}
#endif

	private func save() {
		let totalSeconds = (durationMinutes * 60) + durationSeconds
		let totalSurfaceInterval = (surfaceIntervalHours * 3600) + (surfaceIntervalMinutes * 60) + surfaceIntervalSeconds

		let parsedTags = tags
			.split(separator: ",")
			.map { $0.trimmingCharacters(in: .whitespaces) }
			.filter { !$0.isEmpty }

		let waterTempMetric: Double? = Double(waterTemp).map { units.tempToMetric($0) }
		let airTempMetric: Double? = Double(airTemp).map { units.tempToMetric($0) }
		let visibilityMetric: Double? = Double(visibilityText).map { units.depthToMetric($0) }

		let startLat = Double(startLatitudeText)
		let startLng = Double(startLongitudeText)
		let endLat = Double(endLatitudeText)
		let endLng = Double(endLongitudeText)

#if !os(macOS)
		let finalSignatureData = verificationSignatureData ?? renderSignatureToImageData(signatureDrawing)
#else
		let finalSignatureData = verificationSignatureData
#endif

		if let d = dive {
			// Edit existing
			d.diveNumber = diveNumber
			d.title = title
			d.date = date
			d.maxDepthMeters = units.depthToMetric(maxDepth)
			d.durationSeconds = totalSeconds
			d.surfaceIntervalSeconds = totalSurfaceInterval > 0 ? totalSurfaceInterval : nil
			d.waterTempCelsius = waterTempMetric
			d.airTempCelsius = airTempMetric
			d.visibilityMeters = visibilityMetric
			d.waterType = waterType
			d.current = current
			d.waveConditions = waves
			d.weather = weather
			d.suitType = suitType
			d.weightKg = weight > 0 ? units.weightToMetric(weight) : nil
			d.diveGuide = diveGuide.isEmpty ? nil : diveGuide
			d.diveOperator = diveOperator.isEmpty ? nil : diveOperator
			d.diveBoat = diveBoat.isEmpty ? nil : diveBoat
			d.rating = rating
			d.notes = notes
			d.tags = parsedTags
			d.startLatitude = startLat
			d.startLongitude = startLng
			d.endLatitude = endLat
			d.endLongitude = endLng
			d.logbookImageData = logbookImageData
			d.logbookImageFilename = logbookImageFilename
			d.verificationSignatureData = finalSignatureData
			d.site = selectedSite
			d.trip = selectedTrip
			d.certification = selectedCertification
			d.equipment = allEquipment.filter { selectedEquipment.contains($0.persistentModelID) }
			d.buddies = allBuddies.filter { selectedBuddies.contains($0.persistentModelID) }
			saveTanks(to: d)
		} else {
			let newDive = Dive(
				diveNumber: diveNumber,
				date: date,
				title: title,
				maxDepthMeters: units.depthToMetric(maxDepth),
				durationSeconds: totalSeconds,
				waterTempCelsius: waterTempMetric,
				airTempCelsius: airTempMetric,
				visibilityMeters: visibilityMetric,
				waterType: waterType,
				current: current,
				waveConditions: waves,
				weather: weather,
				suitType: suitType,
				weightKg: weight > 0 ? units.weightToMetric(weight) : nil,
				diveGuide: diveGuide.isEmpty ? nil : diveGuide,
				diveOperator: diveOperator.isEmpty ? nil : diveOperator,
				diveBoat: diveBoat.isEmpty ? nil : diveBoat,
				rating: rating,
				notes: notes,
				tags: parsedTags,
				startLatitude: startLat,
				startLongitude: startLng,
				endLatitude: endLat,
				endLongitude: endLng,
				importSource: "Manual",
				site: selectedSite,
				trip: selectedTrip
			)
			modelContext.insert(newDive)
			newDive.certification = selectedCertification
			newDive.logbookImageData = logbookImageData
			newDive.logbookImageFilename = logbookImageFilename
			newDive.verificationSignatureData = finalSignatureData
			newDive.surfaceIntervalSeconds = totalSurfaceInterval > 0 ? totalSurfaceInterval : nil
			newDive.equipment = allEquipment.filter { selectedEquipment.contains($0.persistentModelID) }
			newDive.buddies = allBuddies.filter { selectedBuddies.contains($0.persistentModelID) }
			saveTanks(to: newDive)
		}

		dismiss()
	}
}

// MARK: - Section Views

private struct BasicInformationSection: View {
	@Binding var diveNumber: Int
	@Binding var title: String
	@Binding var date: Date

	var body: some View {
		Section {
			LabeledContent("Dive Number") {
				TextField("Dive Number", value: $diveNumber, format: .number)
					.labelsHidden()
#if !os(macOS)
					.keyboardType(.numberPad)
#endif
					.multilineTextAlignment(.trailing)
			}
			TextField("Title (optional)", text: $title)
			DatePicker("Date & Time", selection: $date)
		} header: {
			Text("Basic Information")
		} footer: {
			Text("Enter a custom title to override the default title showing the dive site or dive number.")
		}
	}
}

private struct LocationSection: View {
	@Binding var selectedSite: DiveSite?
	var availableSites: [DiveSite]
	@Binding var showingNewSite: Bool
	@Binding var startLatitudeText: String
	@Binding var startLongitudeText: String
	@Binding var endLatitudeText: String
	@Binding var endLongitudeText: String

	private var sortedSites: [DiveSite] {
		availableSites.sorted {
			$0.name.markdownStripped.localizedStandardCompare($1.name.markdownStripped) == .orderedAscending
		}
	}

	var body: some View {
		Section {
			Picker("Dive Site", selection: $selectedSite) {
				Text("None").tag(DiveSite?.none)
				ForEach(sortedSites) { site in
					Text(LocalizedStringKey(site.name)).tag(DiveSite?.some(site))
				}
			}
			.listRowSeparator(.hidden, edges: .bottom)
			HStack {
				Spacer()
				Button {
					showingNewSite = true
				} label: {
					Label("New Dive Site…", systemImage: "plus.circle")
				}
			}
			.alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
			LabeledContent("Entry Latitude") {
				TextField("Entry Latitude", text: $startLatitudeText, prompt: Text("(optional)"))
					.labelsHidden()
#if !os(macOS)
					.keyboardType(.numbersAndPunctuation)
#endif
					.multilineTextAlignment(.trailing)
			}
			LabeledContent("Entry Longitude") {
				TextField("Entry Longitude", text: $startLongitudeText, prompt: Text("(optional)"))
					.labelsHidden()
#if !os(macOS)
					.keyboardType(.numbersAndPunctuation)
#endif
					.multilineTextAlignment(.trailing)
			}
			LabeledContent("Exit Latitude") {
				TextField("Exit Latitude", text: $endLatitudeText, prompt: Text("(optional)"))
					.labelsHidden()
#if !os(macOS)
					.keyboardType(.numbersAndPunctuation)
#endif
					.multilineTextAlignment(.trailing)
			}
			LabeledContent("Exit Longitude") {
				TextField("Exit Longitude", text: $endLongitudeText, prompt: Text("(optional)"))
					.labelsHidden()
#if !os(macOS)
					.keyboardType(.numbersAndPunctuation)
#endif
					.multilineTextAlignment(.trailing)
			}
		} header: {
			Text("Location")
		} footer: {
			Text("Optionally record GPS coordinates for the entry and exit points of the dive.")
		}
	}
}

private struct DepthTimeSection: View {
	@Binding var maxDepth: Double
	@Binding var durationMinutes: Int
	@Binding var durationSeconds: Int
	@Binding var surfaceIntervalHours: Int
	@Binding var surfaceIntervalMinutes: Int
	@Binding var surfaceIntervalSeconds: Int
	var units: UnitFormatter

	var body: some View {
		Section("Depth & Time") {
			LabeledContent(units.depthFieldLabel) {
				TextField(units.depthFieldLabel, value: $maxDepth, format: .number.precision(.fractionLength(0)), prompt: Text("Dive Number"))
					.labelsHidden()
#if !os(macOS)
					.keyboardType(.decimalPad)
#endif
					.multilineTextAlignment(.trailing)
			}
			HStack {
				Text("Duration")
				Spacer()
				TextField("", value: $durationMinutes, format: .number.precision(.fractionLength(0)))
#if !os(macOS)
					.keyboardType(.numberPad)
#endif
					.multilineTextAlignment(.trailing)
					.frame(width: 50)
				Text("min")
				TextField("", value: $durationSeconds, format: .number.precision(.fractionLength(0)))
#if !os(macOS)
					.keyboardType(.numberPad)
#endif
					.multilineTextAlignment(.trailing)
					.frame(width: 40)
				Text("sec")
			}
			HStack {
				Text("Surf Intvl")
				Spacer()
				TextField("", value: $surfaceIntervalHours, format: .number.precision(.fractionLength(0)))
#if !os(macOS)
					.keyboardType(.numberPad)
#endif
					.multilineTextAlignment(.trailing)
					.frame(width: 50)
				Text("hrs")
				TextField("", value: $surfaceIntervalMinutes, format: .number.precision(.fractionLength(0)))
#if !os(macOS)
					.keyboardType(.numberPad)
#endif
					.multilineTextAlignment(.trailing)
					.frame(width: 50)
				Text("min")
				TextField("", value: $surfaceIntervalSeconds, format: .number.precision(.fractionLength(0)))
#if !os(macOS)
					.keyboardType(.numberPad)
#endif
					.multilineTextAlignment(.trailing)
					.frame(width: 40)
				Text("sec")
			}
		}
	}
}

private struct ConditionsSection: View {
	@Binding var waterTemp: String
	@Binding var airTemp: String
	@Binding var visibilityText: String
	@Binding var waterType: WaterType?
	@Binding var current: Current?
	@Binding var waves: WaveConditions?
	@Binding var weather: String
	var units: UnitFormatter

	var body: some View {
		Section("Conditions") {
			LabeledContent(units.waterTempFieldLabel) {
				TextField(units.waterTempFieldLabel, text: $waterTemp, prompt: Text(units.tempLabel))
					.labelsHidden()
#if !os(macOS)
					.keyboardType(.decimalPad)
#endif
					.multilineTextAlignment(.trailing)
			}
			LabeledContent(units.airTempFieldLabel) {
				TextField(units.airTempFieldLabel, text: $airTemp, prompt: Text(units.tempLabel))
					.labelsHidden()
#if !os(macOS)
					.keyboardType(.decimalPad)
#endif
					.multilineTextAlignment(.trailing)
			}
			LabeledContent(units.visibilityFieldLabel) {
				TextField(units.visibilityFieldLabel, text: $visibilityText, prompt: Text(units.depthLabel))
					.labelsHidden()
#if !os(macOS)
					.keyboardType(.numberPad)
#endif
					.multilineTextAlignment(.trailing)
			}
			Picker("Water Type", selection: $waterType) {
				Text("None").tag(WaterType?.none)
				ForEach(WaterType.allCases, id: \.self) { t in
					Text(t.rawValue).tag(WaterType?.some(t))
				}
			}
			Picker("Current", selection: $current) {
				Text("None").tag(Current?.none)
				ForEach(Current.allCases, id: \.self) { c in
					Text(c.rawValue).tag(Current?.some(c))
				}
			}
			Picker("Waves", selection: $waves) {
				Text("None").tag(WaveConditions?.none)
				ForEach(WaveConditions.allCases, id: \.self) { w in
					Text(w.rawValue).tag(WaveConditions?.some(w))
				}
			}
			TextField("Weather", text: $weather)
		}
	}
}

private struct GearSection: View {
	@Binding var suitType: SuitType?
	@Binding var weight: Double
	var units: UnitFormatter

	var body: some View {
		Section("Suit") {
			Picker("Suit", selection: $suitType) {
				Text("None").tag(SuitType?.none)
				ForEach(SuitType.allCases, id: \.self) { s in
					Text(s.rawValue).tag(SuitType?.some(s))
				}
			}
			LabeledContent(units.weightFieldLabel) {
				TextField(units.weightFieldLabel, value: $weight, format: .number.precision(.fractionLength(0)), prompt: Text(units.weightFieldLabel))
					.labelsHidden()
#if !os(macOS)
					.keyboardType(.numberPad)
#endif
					.multilineTextAlignment(.trailing)
			}
		}
	}
}

private struct TanksSection: View {
	@Binding var tankEntries: [TankEntry]
	var availableGasMixes: [GasMix]
	var availableTanks: [Equipment]
	@Binding var showingNewGasMix: Bool
	var units: UnitFormatter

	var body: some View {
		Section {
			if tankEntries.isEmpty {
				Text("No tanks added")
					.foregroundStyle(.secondary)
			} else {
				ForEach($tankEntries) { $entry in
					TankEntryRow(
						entry: $entry,
						index: tankEntries.firstIndex(where: { $0.id == entry.id }) ?? 0,
						availableGasMixes: availableGasMixes,
						availableTanks: availableTanks,
						showingNewGasMix: $showingNewGasMix,
						units: units,
						onRemove: {
							tankEntries.removeAll { $0.id == entry.id }
						}
					)
				}
			}
			HStack {
				Spacer()
				Button {
					tankEntries.append(TankEntry())
				} label: {
					Label("Add Tank…", systemImage: "plus.circle")
				}
			}
		} header: {
			Text("Tanks")
		} footer: {
			Text("Add one tank entry per gas source used during the dive.")
		}
	}
}

private struct TankEntryRow: View {
	@Binding var entry: TankEntry
	let index: Int
	var availableGasMixes: [GasMix]
	var availableTanks: [Equipment]
	@Binding var showingNewGasMix: Bool
	var units: UnitFormatter
	var onRemove: () -> Void

	var body: some View {
		Group {
			HStack {
				Text("Tank \(index + 1)")
					.font(.headline)
				Spacer()
				Button("Remove", systemImage: "trash", role: .destructive) {
					onRemove()
				}
				.labelStyle(.iconOnly)
				.buttonStyle(.borderless)
				.foregroundStyle(.red)
			}
			Picker("Equipment", selection: $entry.equipment) {
				Text("None").tag(Equipment?.none)
				ForEach(availableTanks) { tank in
					Text(tank.name).tag(Equipment?.some(tank))
				}
			}
			Picker("Gas Mix", selection: $entry.gasMix) {
				Text("None").tag(GasMix?.none)
				ForEach(availableGasMixes) { mix in
					Text(mix.displayName).tag(GasMix?.some(mix))
				}
			}
			.listRowSeparator(.hidden, edges: .bottom)
			HStack {
				Spacer()
				Button {
					showingNewGasMix = true
				} label: {
					Label("New Gas Mix…", systemImage: "plus.circle")
				}
			}
			LabeledContent(units.startPressureFieldLabel) {
				TextField(units.startPressureFieldLabel, value: $entry.startPressureDisplay, format: .number.precision(.fractionLength(0)), prompt: Text(units.pressureLabel))
					.labelsHidden()
#if !os(macOS)
					.keyboardType(.numberPad)
#endif
					.multilineTextAlignment(.trailing)
			}
			LabeledContent(units.endPressureFieldLabel) {
				TextField(units.endPressureFieldLabel, value: $entry.endPressureDisplay, format: .number.precision(.fractionLength(0)), prompt: Text(units.pressureLabel))
					.labelsHidden()
#if !os(macOS)
					.keyboardType(.numberPad)
#endif
					.multilineTextAlignment(.trailing)
			}
		}
	}
}

struct TankEntry: Identifiable {
	let id: UUID
	var externalId: String?
	var equipment: Equipment?
	var gasMix: GasMix?
	var startPressureDisplay: Double?
	var endPressureDisplay: Double?

	init(
		id: UUID = UUID(),
		externalId: String? = UUID().uuidString,
		equipment: Equipment? = nil,
		gasMix: GasMix? = nil,
		startPressureDisplay: Double? = nil,
		endPressureDisplay: Double? = nil
	) {
		self.id = id
		self.externalId = externalId
		self.equipment = equipment
		self.gasMix = gasMix
		self.startPressureDisplay = startPressureDisplay
		self.endPressureDisplay = endPressureDisplay
	}

	init(from tank: Tank, units: UnitFormatter) {
		self.id = UUID()
		self.externalId = tank.externalId
		self.equipment = tank.equipment
		self.gasMix = tank.gasMix
		self.startPressureDisplay = tank.startPressureBar.map { units.pressureForDisplay($0) }
		self.endPressureDisplay = tank.endPressureBar.map { units.pressureForDisplay($0) }
	}
}

private struct EquipmentSelectionSection: View {
	var allEquipment: [Equipment]
	@Binding var selectedEquipment: Set<PersistentIdentifier>

	var body: some View {
		Section("Equipment") {
			if allEquipment.isEmpty {
				Text("No equipment added yet")
					.foregroundStyle(.secondary)
			} else {
				ForEach(allEquipment.filter { !$0.isRetired }) { item in
					Toggle(isOn: Binding(
						get: { selectedEquipment.contains(item.persistentModelID) },
						set: { isOn in
							if isOn {
								selectedEquipment.insert(item.persistentModelID)
							} else {
								selectedEquipment.remove(item.persistentModelID)
							}
						}
					)) {
						VStack(alignment: .leading) {
							Text(item.name)
							if !item.manufacturer.isEmpty {
								Text(item.manufacturer)
									.font(.caption)
									.foregroundStyle(.secondary)
							}
						}
					}
					.disabled(item.isRetired)
				}
			}
		}
	}
}

private struct BuddySelectionSection: View {
	var allBuddies: [Buddy]
	@Binding var selectedBuddies: Set<PersistentIdentifier>

	var body: some View {
		Section("Buddies") {
			if allBuddies.isEmpty {
				Text("No buddies added yet")
					.foregroundStyle(.secondary)
			} else {
				ForEach(allBuddies.filter { !$0.isRetired }) { buddy in
					Toggle(isOn: Binding(
						get: { selectedBuddies.contains(buddy.persistentModelID) },
						set: { isOn in
							if isOn {
								selectedBuddies.insert(buddy.persistentModelID)
							} else {
								selectedBuddies.remove(buddy.persistentModelID)
							}
						}
					)) {
						HStack {
							BuddyPhoto(photoData: buddy.photoData, size: 24)
							Text(buddy.formattedName)
						}
						.lineLimit(1)
					}
				}
			}
		}
	}
}

private struct TripSelectionSection: View {
	@Binding var selectedTrip: Trip?
	var availableTrips: [Trip]

	var body: some View {
		Section("Trip") {
			Picker("Trip", selection: $selectedTrip) {
				Text("None").tag(Trip?.none)
				ForEach(availableTrips) { trip in
					Text(trip.name).tag(Trip?.some(trip))
				}
			}
		}
	}
}

private struct CertificationSelectionSection: View {
	@Binding var selectedCertification: Certification?
	var availableCertifications: [Certification]

	var body: some View {
		Section {
			Picker("Certification", selection: $selectedCertification) {
				Text("None").tag(Certification?.none)
				ForEach(availableCertifications) { cert in
					Text(cert.name).tag(Certification?.some(cert))
				}
			}
		} header: {
			Text("Certification")
		} footer: {
			Text("If this dive was performed in fulfillment of a certification, select it here.")
		}
	}
}

private struct PeopleSection: View {
	@Binding var diveGuide: String
	@Binding var diveOperator: String
	@Binding var diveBoat: String

	var body: some View {
		Section("Operator") {
			LabeledContent("Dive Guide") {
				TextField("Dive Guide", text: $diveGuide, prompt: Text("(optional)"))
					.labelsHidden()
					.multilineTextAlignment(.trailing)
			}
			LabeledContent("Dive Operator") {
				TextField("Dive Operator", text: $diveOperator, prompt: Text("(optional)"))
					.labelsHidden()
					.multilineTextAlignment(.trailing)
			}
			LabeledContent("Dive Boat") {
				TextField("Dive Boat", text: $diveBoat, prompt: Text("(optional)"))
					.labelsHidden()
					.multilineTextAlignment(.trailing)
			}
		}
	}
}

private struct RatingNotesSection: View {
	@Binding var rating: Int
	@Binding var notes: String
	@Binding var tags: String

	var body: some View {
		Section {
			LabeledContent("Rating") {
				StarRatingView(rating: rating, interactive: true) { rating = $0 }
			}
			ZStack(alignment: .topLeading) {
				if notes.isEmpty {
					Text("Notes")
						.foregroundStyle(.tertiary)
						.padding(.top, 8)
						.padding(.leading, 4)
				}
				TextEditor(text: $notes)
					.frame(minHeight: 200)
			}
			TextField("Tags (comma-separated)", text: $tags)
#if !os(macOS)
				.textInputAutocapitalization(.never)
#endif
		} header: {
			Text("Rating & Notes")
		} footer: {
			Text("You can use text formatting (bold, italics, links, etc.) using inline Markdown syntax.")
		}
	}
}

private struct LogbookImageSection: View {
	@Binding var imageData: Data?
	@Binding var photoItem: PhotosPickerItem?
	@Binding var showingFileImporter: Bool

	var body: some View {
		Section {
			if let imageData, let image = makeImage(from: imageData) {
				image
					.resizable()
					.scaledToFit()
					.frame(maxHeight: 200)
					.clipShape(.rect(cornerRadius: 8))
				Button("Remove Image", systemImage: "trash", role: .destructive) {
					self.imageData = nil
					photoItem = nil
				}
			} else {
				PhotosPicker(selection: $photoItem, matching: .images) {
					Label("Choose from Photos", systemImage: "photo.on.rectangle")
				}
				Button("Choose from Files", systemImage: "folder") {
					showingFileImporter = true
				}
			}
		} header: {
			Text("Log Book Page")
		} footer: {
			Text("Optionally upload an image of a written log book page.")
		}
	}

	private func makeImage(from data: Data) -> Image? {
#if canImport(UIKit)
		guard let uiImage = UIImage(data: data) else { return nil }
		return Image(uiImage: uiImage)
#elseif canImport(AppKit)
		guard let nsImage = NSImage(data: data) else { return nil }
		return Image(nsImage: nsImage)
#endif
	}
}

#if !os(macOS)
private struct VerificationSignatureSection: View {
	@Binding var signatureData: Data?
	@Binding var drawing: PKDrawing

	var body: some View {
		Section {
			if let signatureData, let image = makeImage(from: signatureData) {
				image
					.renderingMode(.template)
					.resizable()
					.scaledToFit()
					.foregroundStyle(.primary)
					.frame(maxHeight: 150)
					.clipShape(.rect(cornerRadius: 8))
				Button("Clear Signature", role: .destructive) {
					self.signatureData = nil
					drawing = PKDrawing()
				}
			} else {
				SignatureCanvasView(drawing: $drawing)
					.frame(height: 150)
					.clipShape(.rect(cornerRadius: 8))
					.overlay(
						RoundedRectangle(cornerRadius: 8)
							.stroke(.secondary.opacity(0.5), lineWidth: 1)
					)
				if !drawing.strokes.isEmpty {
					Button("Clear Drawing", systemImage: "eraser", role: .destructive) {
						drawing = PKDrawing()
					}
				}
			}
		} header: {
			Text("Verification Signature")
		} footer: {
			Text("Sign with your finger or Apple Pencil to verify this dive log entry.")
		}
	}

	private func makeImage(from data: Data) -> Image? {
		guard let uiImage = UIImage(data: data) else { return nil }
		return Image(uiImage: uiImage)
	}
}
#else
/// macOS variant: displays an existing signature and lets the user clear it.
/// Signing itself isn't available on the Mac, since PencilKit's canvas is iOS/iPadOS-only.
private struct VerificationSignatureSection: View {
	@Binding var signatureData: Data?

	var body: some View {
		Section {
			if let signatureData, let image = makeImage(from: signatureData) {
				image
					.renderingMode(.template)
					.resizable()
					.scaledToFit()
					.foregroundStyle(.primary)
					.frame(maxHeight: 150)
					.clipShape(.rect(cornerRadius: 8))
			}
			Button("Clear Signature", systemImage: "trash", role: .destructive) {
				signatureData = nil
			}
		} header: {
			Text("Verification Signature")
		} footer: {
			Text("Signatures can be added on iPhone or iPad.")
		}
	}

	private func makeImage(from data: Data) -> Image? {
		guard let nsImage = NSImage(data: data) else { return nil }
		return Image(nsImage: nsImage)
	}
}
#endif

#Preview("New Dive") {
	DiveEntryView(dive: nil)
		.modelContainer(PreviewContainer.container)
}

#Preview("Edit Dive") {
	let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
	// swiftlint:disable force_try
	let container = try! ModelContainer(
		for: Dive.self, GasMix.self, DiveSite.self, DepthSample.self, Equipment.self, ServiceRecord.self, Buddy.self, Trip.self, Photo.self, Tank.self,
		configurations: config
	)
	PreviewContainer.insertSampleData(into: container)
	let dive = try! container.mainContext.fetch(FetchDescriptor<Dive>()).first!
	// swiftlint:enable force_try
	return DiveEntryView(dive: dive)
		.modelContainer(container)
}
