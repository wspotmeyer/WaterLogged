//
//  ContactDetailsTests.swift
//  WaterLoggedTests
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

import Testing
import Contacts
@testable import WaterLogged

struct ContactDetailsTests {

	@Test func copiesTheFirstValueOfEachField() {
		let contact = CNMutableContact()
		contact.givenName = "Jacques"
		contact.familyName = "Cousteau"
		let address = CNMutablePostalAddress()
		address.street = "1 Ocean Way"
		address.city = "Monaco"
		contact.postalAddresses = [CNLabeledValue(label: CNLabelHome, value: address)]
		contact.phoneNumbers = [
			CNLabeledValue(label: CNLabelPhoneNumberMain, value: CNPhoneNumber(stringValue: "+377 1234")),
			CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: "+377 5678"))
		]
		contact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: "jc@example.com" as NSString)]
		contact.urlAddresses = [CNLabeledValue(label: CNLabelURLAddressHomePage, value: "https://example.com" as NSString)]

		let details = ContactDetails(contact)
		#expect(details.givenName == "Jacques")
		#expect(details.familyName == "Cousteau")
		#expect(details.address?.street == "1 Ocean Way")
		#expect(details.address?.city == "Monaco")
		#expect(details.telephone == "+377 1234")
		#expect(details.email == "jc@example.com")
		#expect(details.webPage == "https://example.com")
		#expect(details.photoData == nil)
	}

	@Test func missingMultiValueFieldsStayNil() {
		let details = ContactDetails(CNMutableContact())
		#expect(details.address == nil)
		#expect(details.telephone == nil)
		#expect(details.email == nil)
		#expect(details.webPage == nil)
	}
}
