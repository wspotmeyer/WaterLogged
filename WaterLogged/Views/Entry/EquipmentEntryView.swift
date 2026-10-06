//
//  EquipmentEntryView.swift
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
import PhotosUI

struct EquipmentEntryView: View {
	@Environment(\.modelContext) private var modelContext
	@Environment(\.dismiss) private var dismiss

	let equipment: Equipment?
	var onDelete: (() -> Void)?

	@State private var name = ""
	@State private var type: EquipmentType = .miscellaneous
	@State private var manufacturer = ""
	@State private var model = ""
	@State private var serialNumber = ""
	@State private var purchaseDate: Date?
	@State private var purchasePrice: String = ""
	@State private var storeName = ""
	@State private var storeURL = ""
	@State private var warranty = ""
	@State private var notes = ""
	@State private var photoData: Data?
	@State private var photoItem: PhotosPickerItem?
	@State private var showingFileImporter = false
	@State private var isRetired = false
	@State private var autoAddToDives = false

	private var isEditing: Bool { equipment != nil }

	@State private var showingDeleteConfirmation = false

	var body: some View {
		NavigationStack {
			Form {
				Group {
					Section("Equipment") {
						LabeledContent("Name") {
							TextField("Name", text: $name, prompt: Text("(required)"))
								.labelsHidden()
								.multilineTextAlignment(.trailing)
						}
						Picker("Type", selection: $type) {
							ForEach(EquipmentType.allCases) { equipmentType in
								Text(equipmentType.label)
									.tag(equipmentType)
							}
						}
						LabeledContent("Manufacturer") {
							TextField("Manufacturer", text: $manufacturer, prompt: Text("(optional)"))
								.labelsHidden()
								.multilineTextAlignment(.trailing)
						}
						LabeledContent("Model") {
							TextField("Model", text: $model, prompt: Text("(optional)"))
								.labelsHidden()
								.multilineTextAlignment(.trailing)
						}
						LabeledContent("Serial Number") {
							TextField("Serial Number", text: $serialNumber, prompt: Text("(optional)"))
								.labelsHidden()
								.multilineTextAlignment(.trailing)
						}
					}

					EquipmentPhotoSection(
						photoData: $photoData,
						photoItem: $photoItem,
						showingFileImporter: $showingFileImporter
					)

					Section("Purchase") {
						DatePicker("Purchase Date", selection: Binding(
							get: { purchaseDate ?? .now },
							set: { purchaseDate = $0 }
						), displayedComponents: .date)
						LabeledContent("Purchase Price") {
							TextField("Purchase Price", text: $purchasePrice, prompt: Text("(optional)"))
								.labelsHidden()
#if !os(macOS)
								.keyboardType(.decimalPad)
#endif
								.multilineTextAlignment(.trailing)
						}
						LabeledContent("Store Name") {
							TextField("Store Name", text: $storeName, prompt: Text("(optional)"))
								.labelsHidden()
								.multilineTextAlignment(.trailing)
						}
						LabeledContent("Store URL") {
							TextField("Store URL", text: $storeURL, prompt: Text("(optional)"))
								.labelsHidden()
#if !os(macOS)
								.keyboardType(.URL)
								.textInputAutocapitalization(.never)
#endif
								.multilineTextAlignment(.trailing)
								.lineLimit(1)
						}
					}

					Section {
						PlaceholderTextEditor(placeholder: "Warranty Information", text: $warranty)
					} header: {
						Text("Warranty Information")
					} footer: {
						Text(PlaceholderTextEditor.markdownHint)
					}

					Section {
						PlaceholderTextEditor(placeholder: "Notes", text: $notes)
					} header: {
						Text("Notes")
					} footer: {
						Text(PlaceholderTextEditor.markdownHint)
					}

					Section {
						Toggle("Retired", isOn: $isRetired)
						Toggle("Auto-add to New Dives", isOn: $autoAddToDives)
					} header: {
						Text("Options")
					} footer: {
						Text("Retired equipment will not be shown in the list of equipment to add to a dive. Auto-add will add the equipment to any new dives you create.")
					}
					if isEditing {
						DeleteItemSection(title: "Delete This Equipment", isConfirming: $showingDeleteConfirmation)
					}
				}
				.tileListRowBackground()
			}
			.entryFormChrome(
				isEditing ? "Edit Equipment" : "New Equipment",
				canSave: !name.isEmpty,
				onSave: {
					save()
					dismiss()
				},
				onCancel: { dismiss() }
			)
			.onAppear {
				if let equipment {
					name = equipment.name
					type = equipment.resolvedType
					manufacturer = equipment.manufacturer
					model = equipment.model
					serialNumber = equipment.serialNumber
					purchaseDate = equipment.purchaseDate
					if let price = equipment.purchasePrice {
						purchasePrice = String(price)
					}
					storeName = equipment.storeName
					storeURL = equipment.storeURL
					warranty = equipment.warranty
					notes = equipment.notes
					photoData = equipment.photoData
					isRetired = equipment.isRetired
					autoAddToDives = equipment.autoAddToDives
				}
			}
			.onChange(of: photoItem) { _, newItem in
				Task { photoData = await ImageFileHelper.loadData(from: newItem) }
			}
			.fileImporter(
				isPresented: $showingFileImporter,
				allowedContentTypes: ImageFileHelper.importableTypes
			) { result in
				guard let url = try? result.get() else { return }
				guard url.startAccessingSecurityScopedResource() else { return }
				defer { url.stopAccessingSecurityScopedResource() }
				photoData = try? Data(contentsOf: url)
			}
			.deleteConfirmation(
				"Delete This Equipment?",
				isPresented: $showingDeleteConfirmation,
				message: "This will permanently delete this equipment and all its service records."
			) {
				dismiss()
				onDelete?()
			}
		}
#if os(macOS)
		.frame(minWidth: 400, idealWidth: 480, minHeight: 450, idealHeight: 550)
#endif
	}

	private func save() {
		let parsedPrice = Double(purchasePrice)

		if let equipment {
			equipment.name = name
			equipment.type = type
			equipment.manufacturer = manufacturer
			equipment.model = model
			equipment.serialNumber = serialNumber
			equipment.purchaseDate = purchaseDate
			equipment.purchasePrice = parsedPrice
			equipment.storeName = storeName
			equipment.storeURL = storeURL
			equipment.warranty = warranty
			equipment.notes = notes
			equipment.photoData = photoData
			equipment.isRetired = isRetired
			equipment.autoAddToDives = autoAddToDives
		} else {
			let newEquipment = Equipment(
				name: name,
				type: type,
				manufacturer: manufacturer,
				model: model,
				serialNumber: serialNumber,
				purchaseDate: purchaseDate,
				purchasePrice: parsedPrice,
				storeName: storeName,
				storeURL: storeURL,
				warranty: warranty,
				notes: notes,
				photoData: photoData,
				isRetired: isRetired,
				autoAddToDives: autoAddToDives
			)
			modelContext.insert(newEquipment)
		}
	}
}

// MARK: - Photo Section

private struct EquipmentPhotoSection: View {
	@Binding var photoData: Data?
	@Binding var photoItem: PhotosPickerItem?
	@Binding var showingFileImporter: Bool

	var body: some View {
		Section("Photo") {
			if let photoData, let image = makeDisplayImage(from: photoData) {
				image
					.resizable()
					.scaledToFit()
					.frame(maxHeight: 200)
					.clipShape(.rect(cornerRadius: 8))
				Button("Remove Photo", role: .destructive) {
					self.photoData = nil
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
		}
	}
}

#Preview("New Equipment") {
	EquipmentEntryView(equipment: nil)
		.modelContainer(PreviewContainer.container)
}
