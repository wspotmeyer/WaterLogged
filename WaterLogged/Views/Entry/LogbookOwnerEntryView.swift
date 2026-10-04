//
//  LogbookOwnerEntryView.swift
//  WaterLogged
//
//  Created by John Meyer on 4/25/26.
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

struct LogbookOwnerEntryView: View {
	@Environment(\.modelContext) private var modelContext
	@Environment(\.dismiss) private var dismiss
	@Query(sort: \Certification.name) private var certifications: [Certification]

	@State private var owner: LogbookOwner?

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

	@State private var photoItem: PhotosPickerItem?
	@State private var showingContactPicker = false
	@State private var showingFileImporter = false
	@State private var showingAddCertification = false
	@State private var certificationToEdit: Certification?
	@State private var pendingDeleteCertification: Certification?

	private static let allowedImageTypes: [UTType] = [.jpeg, .png, .gif, .tiff]

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
						Text("Optionally import this information from a Contacts record. Doing so will overwrite any existing entries.")
					}
#endif

					Section("Photo") {
						OwnerPhotoPicker(
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

					Section("Certifications") {
						ForEach(certifications) { cert in
							Button {
								certificationToEdit = cert
							} label: {
								HStack {
									VStack(alignment: .leading, spacing: 4) {
										Text(cert.name)
										if !cert.issuingAgency.isEmpty {
											Text(cert.issuingAgency)
												.font(.caption)
												.foregroundStyle(.secondary)
										}
									}
									Spacer()
									Image(systemName: "chevron.right")
										.font(.caption)
										.foregroundStyle(.tertiary)
								}
							}
							.tint(.primary)
						}
						.onDelete { offsets in
							if let index = offsets.first {
								pendingDeleteCertification = certifications[index]
							}
						}

						Button("Add Certification", systemImage: "plus") {
							showingAddCertification = true
						}
					}
				}
				.tileListRowBackground()
			}
			.formStyle(.grouped)
			.appGradientScrollBackground()
			.navigationTitle("Edit Owner")
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
				}
			}
			.onAppear {
				owner = try? LogbookOwner.fetchOrCreate(in: modelContext)
				loadOwner()
			}
			.onChange(of: photoItem) { _, newItem in
				Task { photoData = await loadImageData(from: newItem) }
			}
			.fileImporter(
				isPresented: $showingFileImporter,
				allowedContentTypes: Self.allowedImageTypes
			) { result in
				photoData = loadImageData(from: result)
			}
			.sheet(isPresented: $showingAddCertification) {
				CertificationEntryView(certification: nil, owner: owner)
			}
			.sheet(item: $certificationToEdit) { cert in
				CertificationEntryView(certification: cert)
			}
			.alert("Delete Certification?", isPresented: Binding(
				get: { pendingDeleteCertification != nil },
				set: { if !$0 { pendingDeleteCertification = nil } }
			)) {
				Button("Delete", role: .destructive) {
					if let cert = pendingDeleteCertification {
						modelContext.delete(cert)
					}
					pendingDeleteCertification = nil
				}
				Button("Cancel", role: .cancel) {
					pendingDeleteCertification = nil
				}
			} message: {
				if let cert = pendingDeleteCertification {
					Text("Are you sure you want to delete \"\(cert.name)\"? This cannot be undone.")
				}
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
		}
#if os(macOS)
		.frame(minWidth: 400, idealWidth: 520, minHeight: 550, idealHeight: 700)
#endif
	}

	// MARK: - Data Loading

	private func loadOwner() {
		guard let owner else { return }
		givenName = owner.givenName
		familyName = owner.familyName
		street = owner.street
		city = owner.city
		state = owner.state
		province = owner.province
		postalCode = owner.postalCode
		country = owner.country
		telephone = owner.telephone
		email = owner.email
		webPage = owner.webPage
		photoData = owner.photoData
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
		guard let owner else { return }
		owner.givenName = givenName
		owner.familyName = familyName
		owner.street = street
		owner.city = city
		owner.state = state
		owner.province = province
		owner.postalCode = postalCode
		owner.country = country
		owner.telephone = telephone
		owner.email = email
		owner.webPage = webPage
		owner.photoData = photoData
	}
}

// MARK: - Photo Picker

private struct OwnerPhotoPicker: View {
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

#Preview {
	LogbookOwnerEntryView()
		.modelContainer(PreviewContainer.container)
}
