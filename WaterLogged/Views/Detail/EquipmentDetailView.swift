//
//  EquipmentDetailView.swift
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

struct EquipmentDetailView: View {
	@Environment(\.modelContext) private var modelContext

	let equipment: Equipment
	var onDelete: (() -> Void)?

	@State private var editingEquipment: Equipment?
	@State private var showingAddService = false
	@State private var showingFullScreenPhoto = false
	@State private var isDivesExpanded = false

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 24) {

				// Header
				VStack(alignment: .leading, spacing: 6) {
					if !equipment.name.isEmpty {
						Text(equipment.name)
							.font(.title.bold())
					}
					EquipmentTypeLabel(type: equipment.resolvedType)
						.font(.subheadline)
				}

				if let photoData = equipment.photoData {
					EquipmentPhotoThumbnail(
						photoData: photoData,
						type: equipment.resolvedType,
						showingFullScreen: $showingFullScreenPhoto
					)
				} else {
					EquipmentTypePlaceholder(type: equipment.resolvedType)
				}

				if hasDetails {
					Divider()

					// Details
					DetailSection(title: "Details") {
						if !equipment.manufacturer.isEmpty {
							DetailRow(label: "Manufacturer", value: equipment.manufacturer)
						}
						if !equipment.model.isEmpty {
							DetailRow(label: "Model", value: equipment.model)
						}
						if !equipment.serialNumber.isEmpty {
							DetailRow(label: "Serial Number", value: equipment.serialNumber)
						}
						if let date = equipment.purchaseDate {
							DetailRow(label: "Purchase Date", value: date.formatted(date: .long, time: .omitted))
						}
						if let price = equipment.purchasePrice {
							DetailRow(label: "Purchase Price", value: price.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))
						}
						if !equipment.storeName.isEmpty {
							DetailRow(label: "Store", value: equipment.storeName)
						}
						if !equipment.storeURL.isEmpty {
							if let url = URL(string: equipment.storeURL) {
								DetailRowContent {
									Link("Store Link", destination: url)
								}
								.padding(.top, 2)
							}
						}
					}
				}

				// Warranty
				if !equipment.warranty.isEmpty {
					DetailSection(title: "Warranty Information") {
						Text(LocalizedStringKey(equipment.warranty))
					}
				}

				// Notes
				if !equipment.notes.isEmpty {
					DetailSection(title: "Notes") {
						Text(LocalizedStringKey(equipment.notes))
					}
				}

				// Service History
				DetailSection(title: "Service History") {
					VStack {
						if !sortedServiceHistory.isEmpty {
							ForEach(sortedServiceHistory) { record in
								ServiceRecordRow(record: record)
							}
						}
						Button("Add Service Record", systemImage: "plus") {
							showingAddService = true
						}
						.padding(.top, 4)
					}
				}

				if let dives = equipment.dives, !dives.isEmpty {
					Divider()
					GroupBox {
						if isDivesExpanded {
							VStack(spacing: 0) {
								ForEach(dives.sorted(by: { $0.date < $1.date })) { dive in
									DiveLinkRow(dive: dive)
								}
							}
							.frame(maxWidth: .infinity, alignment: .leading)
						}
					} label: {
						HStack {
							Text("Dives")
								.font(.title2.bold())
							Spacer()
							TimeCount(seconds: equipment.totalDiveTimeSeconds, font: .headline)
							DiveCount(count: dives.count, font: .headline)
							DisclosureToggleButton(isExpanded: $isDivesExpanded, subject: "Dives")
						}
					}
					.tileBackgroundStyle()
				}
			}
			.padding()
			.frame(maxWidth: 700)
			.frame(maxWidth: .infinity)
			.appGradientScrollBackground()
			.navigationTitle(LocalizedStringKey(equipment.name))
#if !os(macOS)
			.navigationBarTitleDisplayMode(.inline)
#endif
			.toolbar {
				ToolbarItem(placement: .primaryAction) {
					Button("Edit", systemImage: "pencil") {
						editingEquipment = equipment
					}
				}
			}
			.sheet(item: $editingEquipment) { editing in
				EquipmentEntryView(equipment: editing) {
					modelContext.delete(editing)
					onDelete?()
				}
			}
			.sheet(isPresented: $showingAddService) {
				ServiceRecordEntryView(record: nil, equipment: equipment)
			}
#if !os(macOS)
			.fullScreenCover(isPresented: $showingFullScreenPhoto) {
				EquipmentFullScreenPhoto(
					photoData: equipment.photoData,
					equipmentName: equipment.name
				)
			}
#else
			.sheet(isPresented: $showingFullScreenPhoto) {
				EquipmentFullScreenPhoto(
					photoData: equipment.photoData,
					equipmentName: equipment.name
				)
			}
#endif
		}
	}

	private var hasDetails: Bool {
		!equipment.model.isEmpty
		|| !equipment.serialNumber.isEmpty
		|| equipment.purchaseDate != nil
		|| equipment.purchasePrice != nil
		|| !equipment.storeName.isEmpty
		|| !equipment.storeURL.isEmpty
	}

	private var sortedServiceHistory: [ServiceRecord] {
		(equipment.serviceHistory ?? []).sorted { $0.serviceDate < $1.serviceDate }
	}
}

// MARK: - Service Record Row

private struct ServiceRecordRow: View {
	let record: ServiceRecord

	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			HStack {
				Text(record.serviceDate.formatted(date: .long, time: .omitted))
					.font(.subheadline)
					.fontWeight(.medium)
				Spacer()
				if !record.servicedBy.isEmpty {
					Text(record.servicedBy)
						.font(.caption)
				}
			}
			if !record.notes.isEmpty {
				Text(record.notes)
					.font(.caption)
			}
		}
		.padding(.vertical, 4)
	}
}

// MARK: - Equipment Photo Views

private struct EquipmentPhotoThumbnail: View {
	let photoData: Data
	let type: EquipmentType
	@Binding var showingFullScreen: Bool

	var body: some View {
		if let image = makeDisplayImage(from: photoData) {
			Button {
				showingFullScreen = true
			} label: {
				image
					.resizable()
					.scaledToFit()
					.frame(maxHeight: 250)
					.clipShape(.rect(cornerRadius: 8))
			}
			.buttonStyle(.plain)
		} else {
			// Photo data that no longer decodes gets the same stand-in as no photo at all.
			EquipmentTypePlaceholder(type: type)
		}
	}
}

/// Stands in for the equipment photo when there isn't one, showing the equipment type's
/// icon at roughly the size the photo would occupy. It sits a little under the photo's
/// 250-point height cap, because solid line art reads larger than a photo of the same size.
private struct EquipmentTypePlaceholder: View {
	let type: EquipmentType

	var body: some View {
		// SF Symbols and custom artwork both scale as ordinary resizable images here, so
		// they fill the same frame regardless of which kind the type uses.
		Group {
			switch type.icon {
				case .system(let name):
					Image(systemName: name)
						.resizable()
				case .custom(let resource):
					Image(resource)
						.resizable()
			}
		}
		.scaledToFit()
		.frame(width: 200, height: 200)
		// Centre in the column the way the photo thumbnail sits.
		.frame(maxWidth: .infinity)
		// The header right above already names the type, so this is purely decorative.
		.accessibilityHidden(true)
	}
}

private struct EquipmentFullScreenPhoto: View {
	@Environment(\.dismiss) private var dismiss

	let photoData: Data?
	let equipmentName: String

	var body: some View {
		NavigationStack {
			Group {
				if let photoData, let image = makeDisplayImage(from: photoData) {
					image
						.resizable()
						.scaledToFit()
				} else {
					ContentUnavailableView("No Image", systemImage: "photo")
				}
			}
			.navigationTitle(equipmentName)
#if !os(macOS)
			.navigationBarTitleDisplayMode(.inline)
#endif
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Done", systemImage: "xmark") { dismiss() }
				}
				if let photoData, let image = makeDisplayImage(from: photoData) {
					ToolbarItem(placement: .primaryAction) {
						ShareLink(
							item: ImageFileHelper.shareableFile(
								data: photoData,
								filename: "\(equipmentName).jpg"
							),
							preview: SharePreview(equipmentName, image: image)
						)
					}
				}
			}
		}
	}
}

#Preview {
	let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
	// swiftlint:disable:next force_try
	let container = try! ModelContainer(for: Equipment.self, ServiceRecord.self, configurations: config)
	let equipment = Equipment(
		name: "Aqua Lung Mikron",
		manufacturer: "Aqua Lung",
		serialNumber: "AL-2024-78901",
		purchaseDate: Calendar.current.date(from: DateComponents(year: 2024, month: 3, day: 10)),
		purchasePrice: 549.99,
		storeName: "Dive Gear Express",
		warranty: "2 years",
		notes: "Primary regulator for warm-water diving."
	)
	container.mainContext.insert(equipment)
	let record = ServiceRecord(
		serviceDate: Calendar.current.date(from: DateComponents(year: 2025, month: 3, day: 10)) ?? .now,
		servicedBy: "Dive Tech Pro",
		notes: "Annual service and inspection"
	)
	record.equipment = equipment
	container.mainContext.insert(record)
	return NavigationStack {
		EquipmentDetailView(equipment: equipment)
	}
	.modelContainer(container)
}
