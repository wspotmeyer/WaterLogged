//
//  Buddy.swift
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

import Foundation
import SwiftData

@Model
final class Buddy {
	var externalId: String = UUID().uuidString
	var givenName: String = ""
	var familyName: String = ""
	var street: String = ""
	var city: String = ""
	var state: String = ""
	var province: String = ""
	var postalCode: String = ""
	var country: String = ""
	var telephone: String = ""
	var email: String = ""
	var webPage: String = ""
	@Attribute(.externalStorage) var photoData: Data?
	var isRetired: Bool = false

	var dives: [Dive]? = []

	/// Formatted display name using the user's locale conventions.
	var formattedName: String {
		var components = PersonNameComponents()
		components.givenName = givenName
		components.familyName = familyName
		let result = components.formatted(.name(style: .long))
		return result.isEmpty ? givenName : result
	}

	init(
		externalId: String = UUID().uuidString,
		givenName: String = "",
		familyName: String = "",
		street: String = "",
		city: String = "",
		state: String = "",
		province: String = "",
		postalCode: String = "",
		country: String = "",
		telephone: String = "",
		email: String = "",
		webPage: String = "",
		photoData: Data? = nil,
		isRetired: Bool = false
	) {
		self.externalId = externalId
		self.givenName = givenName
		self.familyName = familyName
		self.street = street
		self.city = city
		self.state = state
		self.province = province
		self.postalCode = postalCode
		self.country = country
		self.telephone = telephone
		self.email = email
		self.webPage = webPage
		self.photoData = photoData
		self.isRetired = isRetired
	}
}
