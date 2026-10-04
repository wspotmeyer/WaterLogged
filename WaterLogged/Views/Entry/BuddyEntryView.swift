//
//  BuddyEntryView.swift
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
import PhotosUI
import Contacts

struct BuddyEntryView: View {
	@Environment(\.modelContext) private var modelContext
	@Environment(\.dismiss) private var dismiss

	let buddy: Buddy?
	var onDelete: (() -> Void)?

	@State private var givenName = ""
	@State private var familyName = ""
	@State private var street = ""
	@State private var city = ""
	@State private var state = ""
	@State private var province = ""
	@State private var postalCode = ""
	@State private var country = ""
	@State private var telephone = ""
	@State private var email = ""
	@State private var webPage = ""
	@State private var photoData: Data?
	@State private var isRetired = false

	@State private var photoItem: PhotosPickerItem?
	@State private var showingContactPicker = false
	@State private var showingFileImporter = false

	private var isEditing: Bool { buddy != nil }

	@State private var showingDeleteConfirmation = false

	var body: some View {
		NavigationStack {
			Form {
				Group {
#if !os(macOS)
					Section {
						Button("Import from Contacts", systemImage: "person.crop.circle.badge.plus") {
							showingContactPicker = true
						}
					} footer: {
						Text("Optionally import this information from a Contacts record. Doing so will overwrite any existing entries.").foregroundStyle(Color.secondary)
					}
#endif

					Section("Photo") {
						CircularPhotoPicker(
							photoData: $photoData,
							photoItem: $photoItem,
							showingFileImporter: $showingFileImporter
						)
					}

					Section("Name") {
						TextField("First Name", text: $givenName)
						TextField("Last Name", text: $familyName)
					}

					Section("Address") {
						TextField("Street", text: $street)
						TextField("City", text: $city)
						TextField("State", text: $state)
						TextField("Province", text: $province)
						TextField("Postal Code", text: $postalCode)
						TextField("Country", text: $country)
					}

					Section("Options") {
						Toggle("Retired", isOn: $isRetired)
					}

					Section("Communications") {
						TextField("Telephone", text: $telephone)
#if !os(macOS)
							.keyboardType(.phonePad)
#endif
						TextField("Email", text: $email)
#if !os(macOS)
							.keyboardType(.emailAddress)
							.textContentType(.emailAddress)
#endif
						TextField("Web Page", text: $webPage)
#if !os(macOS)
							.keyboardType(.URL)
							.textContentType(.URL)
							.textInputAutocapitalization(.never)
#endif
							.autocorrectionDisabled()
					}
					if isEditing {
						DeleteItemSection(title: "Delete This Buddy", isConfirming: $showingDeleteConfirmation)
					}
				}
				.tileListRowBackground()
			}
			.entryFormChrome(
				isEditing ? "Edit Buddy" : "New Buddy",
				canSave: !(givenName.isEmpty && familyName.isEmpty),
				onSave: {
					save()
					dismiss()
				},
				onCancel: { dismiss() }
			)
			.onAppear { loadBuddy() }
			.onChange(of: photoItem) { _, newItem in
				Task { photoData = await ImageFileHelper.loadData(from: newItem) }
			}
			.fileImporter(
				isPresented: $showingFileImporter,
				allowedContentTypes: ImageFileHelper.importableTypes
			) { result in
				photoData = ImageFileHelper.loadData(from: result)
			}
#if canImport(UIKit)
			.sheet(isPresented: $showingContactPicker) {
				ContactPicker { contact in
					populateFromContact(contact)
				}
			}
#elseif canImport(AppKit)
			.background(
				ContactPickerAnchor(isPresented: $showingContactPicker) { contact in
					populateFromContact(contact)
				}
					.frame(width: 0, height: 0)
			)
#endif
			.deleteConfirmation(
				"Delete This Buddy?",
				isPresented: $showingDeleteConfirmation,
				message: "This will permanently delete this buddy. The buddy will be removed from any associated dives."
			) {
				dismiss()
				onDelete?()
			}
		}
#if os(macOS)
		.frame(minWidth: 400, idealWidth: 520, minHeight: 550, idealHeight: 700)
#endif
	}

	// MARK: - Data Loading

	private func loadBuddy() {
		guard let buddy else { return }
		givenName = buddy.givenName
		familyName = buddy.familyName
		street = buddy.street
		city = buddy.city
		state = buddy.state
		province = buddy.province
		postalCode = buddy.postalCode
		country = buddy.country
		telephone = buddy.telephone
		email = buddy.email
		webPage = buddy.webPage
		photoData = buddy.photoData
		isRetired = buddy.isRetired
	}

	private func populateFromContact(_ contact: CNContact) {
		let details = ContactDetails(contact)
		if let value = details.givenName { givenName = value }
		if let value = details.familyName { familyName = value }
		if let address = details.address {
			street = address.street
			city = address.city
			state = address.state
			postalCode = address.postalCode
			country = address.country
		}
		if let value = details.telephone { telephone = value }
		if let value = details.email { email = value }
		if let value = details.webPage { webPage = value }
		if let value = details.photoData { photoData = value }
	}

	// MARK: - Save

	private func save() {
		if let buddy {
			buddy.givenName = givenName
			buddy.familyName = familyName
			buddy.street = street
			buddy.city = city
			buddy.state = state
			buddy.province = province
			buddy.postalCode = postalCode
			buddy.country = country
			buddy.telephone = telephone
			buddy.email = email
			buddy.webPage = webPage
			buddy.photoData = photoData
			buddy.isRetired = isRetired
		} else {
			let newBuddy = Buddy(
				givenName: givenName,
				familyName: familyName,
				street: street,
				city: city,
				state: state,
				province: province,
				postalCode: postalCode,
				country: country,
				telephone: telephone,
				email: email,
				webPage: webPage,
				photoData: photoData,
				isRetired: isRetired
			)
			modelContext.insert(newBuddy)
		}
	}
}

#Preview("New Buddy") {
	BuddyEntryView(buddy: nil)
		.modelContainer(PreviewContainer.container)
}
