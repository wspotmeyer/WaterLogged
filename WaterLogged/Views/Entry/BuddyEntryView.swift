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
import UniformTypeIdentifiers

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

	private static let allowedImageTypes: [UTType] = [.jpeg, .png, .gif, .tiff]

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
						Text("Optionally import this information from a Contacts record. Doing so will overwrite any existing entries.").foregroundColor(.secondary)
					}
#endif

					Section("Photo") {
						BuddyPhotoPicker(
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
						Section {
							Button("Delete This Buddy", role: .destructive) {
								showingDeleteConfirmation = true
							}
						}
					}
				}
				.tileListRowBackground()
			}
			.formStyle(.grouped)
			.appGradientScrollBackground()
			.navigationTitle(isEditing ? "Edit Buddy" : "New Buddy")
#if !os(macOS)
			.navigationBarTitleDisplayMode(.inline)
#endif
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel", systemImage: "xmark") { dismiss() }
				}
				ToolbarItem(placement: .confirmationAction) {
					Button("Save", systemImage: "checkmark") {
						save()
						dismiss()
					}
					.buttonStyle(.borderedProminent)
					.disabled(givenName.isEmpty && familyName.isEmpty)
				}
			}
			.onAppear { loadBuddy() }
			.onChange(of: photoItem) { _, newItem in
				Task { photoData = await loadImageData(from: newItem) }
			}
			.fileImporter(
				isPresented: $showingFileImporter,
				allowedContentTypes: Self.allowedImageTypes
			) { result in
				photoData = loadImageData(from: result)
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
			.alert("Delete This Buddy?", isPresented: $showingDeleteConfirmation) {
				Button("Delete", role: .destructive) {
					dismiss()
					onDelete?()
				}
				Button("Cancel", role: .cancel) { }
			} message: {
				Text("This will permanently delete this buddy. The buddy will be removed from any associated dives.")
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
		if contact.isKeyAvailable(CNContactGivenNameKey) {
			givenName = contact.givenName
		}
		if contact.isKeyAvailable(CNContactFamilyNameKey) {
			familyName = contact.familyName
		}

		if contact.isKeyAvailable(CNContactPostalAddressesKey),
		   let address = contact.postalAddresses.first?.value {
			street = address.street
			city = address.city
			state = address.state
			postalCode = address.postalCode
			country = address.country
		}

		if contact.isKeyAvailable(CNContactPhoneNumbersKey),
		   let phone = contact.phoneNumbers.first?.value {
			telephone = phone.stringValue
		}

		if contact.isKeyAvailable(CNContactEmailAddressesKey),
		   let emailValue = contact.emailAddresses.first?.value {
			email = emailValue as String
		}

		if contact.isKeyAvailable(CNContactUrlAddressesKey),
		   let urlValue = contact.urlAddresses.first?.value {
			webPage = urlValue as String
		}

		if contact.isKeyAvailable(CNContactImageDataKey), let imageData = contact.imageData {
			photoData = imageData
		} else if contact.isKeyAvailable(CNContactThumbnailImageDataKey),
				  let thumbData = contact.thumbnailImageData {
			photoData = thumbData
		}
	}

	// MARK: - Image Loading

	private func loadImageData(from item: PhotosPickerItem?) async -> Data? {
		guard let item else { return nil }
		return try? await item.loadTransferable(type: Data.self)
	}

	private func loadImageData(from result: Result<URL, Error>) -> Data? {
		guard let url = try? result.get() else { return nil }
		guard url.startAccessingSecurityScopedResource() else { return nil }
		defer { url.stopAccessingSecurityScopedResource() }
		return try? Data(contentsOf: url)
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

// MARK: - Photo Picker

private struct BuddyPhotoPicker: View {
	@Binding var photoData: Data?
	@Binding var photoItem: PhotosPickerItem?
	@Binding var showingFileImporter: Bool

	var body: some View {
		if let photoData, let image = makeImage(from: photoData) {
			HStack {
				Spacer()
				image
					.resizable()
					.scaledToFill()
					.frame(width: 100, height: 100)
					.clipShape(.circle)
				Spacer()
			}
			Button("Remove Photo", systemImage: "trash", role: .destructive) {
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

#Preview("New Buddy") {
	BuddyEntryView(buddy: nil)
		.modelContainer(PreviewContainer.container)
}
