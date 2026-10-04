//
//  ContactDetails.swift
//  WaterLogged
//
//  Created by John Meyer on 10/4/26.
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

import Contacts

/// The fields WaterLogged imports from a Contacts card. A property is `nil` when
/// the card doesn't carry it (or the key wasn't fetched), so applying the result
/// only overwrites the form fields the contact actually supplies.
struct ContactDetails {
	var givenName: String?
	var familyName: String?
	/// Street, city, state, postal code and country of the first postal address.
	var address: CNPostalAddress?
	var telephone: String?
	var email: String?
	var webPage: String?
	/// Full-size image when available, otherwise the thumbnail.
	var photoData: Data?

	init(_ contact: CNContact) {
		if contact.isKeyAvailable(CNContactGivenNameKey) {
			givenName = contact.givenName
		}
		if contact.isKeyAvailable(CNContactFamilyNameKey) {
			familyName = contact.familyName
		}
		if contact.isKeyAvailable(CNContactPostalAddressesKey) {
			address = contact.postalAddresses.first?.value
		}
		if contact.isKeyAvailable(CNContactPhoneNumbersKey) {
			telephone = contact.phoneNumbers.first?.value.stringValue
		}
		if contact.isKeyAvailable(CNContactEmailAddressesKey) {
			email = contact.emailAddresses.first.map { $0.value as String }
		}
		if contact.isKeyAvailable(CNContactUrlAddressesKey) {
			webPage = contact.urlAddresses.first.map { $0.value as String }
		}
		if contact.isKeyAvailable(CNContactImageDataKey), let imageData = contact.imageData {
			photoData = imageData
		} else if contact.isKeyAvailable(CNContactThumbnailImageDataKey) {
			photoData = contact.thumbnailImageData
		}
	}
}
