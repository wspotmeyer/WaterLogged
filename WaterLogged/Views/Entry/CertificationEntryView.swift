//
//  CertificationEntryView.swift
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

struct CertificationEntryView: View {
	@Environment(\.modelContext) private var modelContext
	@Environment(\.dismiss) private var dismiss

	let certification: Certification?
	var owner: LogbookOwner?
	var onDelete: (() -> Void)?

	@State private var name = ""
	@State private var certificationNumber = ""
	@State private var dateAchieved: Date?
	@State private var issuingAgency = ""
	@State private var instructorName = ""
	@State private var instructorNumber = ""
	@State private var diveShop = ""
	@State private var frontImageData: Data?
	@State private var backImageData: Data?

	// Photos picker state
	@State private var frontPhotoItem: PhotosPickerItem?
	@State private var backPhotoItem: PhotosPickerItem?

	// File importer state — single enum to avoid duplicate .fileImporter modifiers
	private enum CardSide { case front, back }
	@State private var activeCardImport: CardSide?

	private var isEditing: Bool { certification != nil }

	@State private var showingDeleteConfirmation = false

	var body: some View {
		NavigationStack {
			Form {
				Group {
					Section("Certification") {
						TextField("Name", text: $name)
						TextField("Certification Number", text: $certificationNumber)
						DatePicker("Date Achieved", selection: Binding(
							get: { dateAchieved ?? .now },
							set: { dateAchieved = $0 }
						), displayedComponents: .date)
						TextField("Issuing Agency", text: $issuingAgency)
					}
					Section("Instructor") {
						TextField("Instructor Name", text: $instructorName)
						TextField("Instructor Number", text: $instructorNumber)
					}
					Section("Dive Shop") {
						TextField("Dive Shop", text: $diveShop)
					}
					Section("Card Front") {
						CardImagePicker(
							imageData: $frontImageData,
							photoItem: $frontPhotoItem,
							showingFileImporter: cardImportBinding(for: .front)
						)
					}
					Section("Card Back") {
						CardImagePicker(
							imageData: $backImageData,
							photoItem: $backPhotoItem,
							showingFileImporter: cardImportBinding(for: .back)
						)
					}
					if isEditing {
						Section {
							Button("Delete Certification", role: .destructive) {
								showingDeleteConfirmation = true
							}
						}
					}
				}
				.tileListRowBackground()
			}
			.entryFormChrome(
				isEditing ? "Edit Certification" : "New Certification",
				canSave: !name.isEmpty,
				onSave: {
					save()
					dismiss()
				},
				onCancel: { dismiss() }
			)
			.onAppear {
				if let certification {
					name = certification.name
					certificationNumber = certification.certificationNumber
					dateAchieved = certification.dateAchieved
					issuingAgency = certification.issuingAgency
					instructorName = certification.instructorName
					instructorNumber = certification.instructorNumber
					diveShop = certification.diveShop
					frontImageData = certification.frontImageData
					backImageData = certification.backImageData
				}
			}
			.onChange(of: frontPhotoItem) { _, newItem in
				Task { frontImageData = await ImageFileHelper.loadData(from: newItem) }
			}
			.onChange(of: backPhotoItem) { _, newItem in
				Task { backImageData = await ImageFileHelper.loadData(from: newItem) }
			}
			.fileImporter(
				isPresented: Binding(
					get: { activeCardImport != nil },
					set: { if !$0 { activeCardImport = nil } }
				),
				allowedContentTypes: ImageFileHelper.importableTypes
			) { [activeCardImport] result in
				let data = ImageFileHelper.loadData(from: result)
				switch activeCardImport {
					case .front: frontImageData = data
					case .back: backImageData = data
					case nil: break
				}
			}
			.alert("Delete Certification?", isPresented: $showingDeleteConfirmation) {
				Button("Delete", role: .destructive) {
					dismiss()
					onDelete?()
				}
				Button("Cancel", role: .cancel) { }
			} message: {
				Text("This will permanently delete this certification.")
			}
		}
#if os(macOS)
		.frame(minWidth: 400, idealWidth: 520, minHeight: 550, idealHeight: 700)
#endif
	}

	// MARK: - Helpers

	private func cardImportBinding(for side: CardSide) -> Binding<Bool> {
		Binding(
			get: { activeCardImport == side },
			set: { activeCardImport = $0 ? side : nil }
		)
	}

	// MARK: - Save

	private func save() {
		if let certification {
			certification.name = name
			certification.certificationNumber = certificationNumber
			certification.dateAchieved = dateAchieved
			certification.issuingAgency = issuingAgency
			certification.instructorName = instructorName
			certification.instructorNumber = instructorNumber
			certification.diveShop = diveShop
			certification.frontImageData = frontImageData
			certification.backImageData = backImageData
		} else {
			let newCert = Certification(
				name: name,
				certificationNumber: certificationNumber,
				dateAchieved: dateAchieved,
				issuingAgency: issuingAgency,
				instructorName: instructorName,
				instructorNumber: instructorNumber,
				diveShop: diveShop
			)
			newCert.frontImageData = frontImageData
			newCert.backImageData = backImageData
			newCert.owner = owner
			modelContext.insert(newCert)
		}
	}
}

// MARK: - Card Image Picker

private struct CardImagePicker: View {
	@Binding var imageData: Data?
	@Binding var photoItem: PhotosPickerItem?
	@Binding var showingFileImporter: Bool

	var body: some View {
		if let imageData, let image = makeDisplayImage(from: imageData) {
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
	}
}

#Preview("New Certification") {
	CertificationEntryView(certification: nil)
		.modelContainer(PreviewContainer.container)
}
