//
//  LogbookOwner.swift
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

import Foundation
import SwiftData

@Model
final class LogbookOwner {
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

	@Relationship(deleteRule: .nullify, inverse: \Certification.owner)
	var certifications: [Certification]? = []

	/// Whether the owner has any filled-in detail worth writing to an export.
	/// A `LogbookOwner` is created on demand, so an untouched profile is empty.
	var hasPersonalDetails: Bool {
		[givenName, familyName, street, city, state, province,
		 postalCode, country, telephone, email, webPage].contains { !$0.isEmpty }
	}

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
		webPage: String = ""
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
	}

	/// Fetches the single LogbookOwner, creating one if it doesn't exist.
	/// Duplicates (see `mergeDuplicates(in:)`) are folded into one along the way.
	static func fetchOrCreate(in context: ModelContext) throws -> LogbookOwner {
		if let owner = try mergeDuplicates(in: context) {
			return owner
		}
		let owner = LogbookOwner()
		context.insert(owner)
		return owner
	}

	/// Folds every LogbookOwner into one and returns it, or returns `nil` when
	/// there is none. Does not save; the caller's save (or autosave) commits it.
	///
	/// With iCloud sync, two devices that each created an owner before their
	/// first sync end up with two. The survivor is the one with the smallest
	/// `externalId`, a choice every device makes identically, so devices
	/// merging concurrently converge on the same record instead of each
	/// deleting the other's. Blank fields on the survivor are filled from the
	/// duplicates, and their certifications move over before they're deleted.
	@discardableResult
	static func mergeDuplicates(in context: ModelContext) throws -> LogbookOwner? {
		let descriptor = FetchDescriptor<LogbookOwner>(sortBy: [SortDescriptor(\.externalId)])
		let owners = try context.fetch(descriptor)
		guard let survivor = owners.first else { return nil }
		for duplicate in owners.dropFirst() {
			survivor.absorb(duplicate)
			context.delete(duplicate)
		}
		return survivor
	}

	/// Copies `other`'s details into any fields this owner left blank, and
	/// takes over its certifications.
	private func absorb(_ other: LogbookOwner) {
		let textFields: [ReferenceWritableKeyPath<LogbookOwner, String>] = [
			\.givenName, \.familyName, \.street, \.city, \.state, \.province,
			\.postalCode, \.country, \.telephone, \.email, \.webPage
		]
		for field in textFields where self[keyPath: field].isEmpty {
			self[keyPath: field] = other[keyPath: field]
		}
		if photoData == nil {
			photoData = other.photoData
		}
		for certification in other.certifications ?? [] {
			certification.owner = self
		}
	}
}
