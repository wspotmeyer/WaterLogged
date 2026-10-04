//
//  XMLBuilderTests.swift
//  WaterLoggedTests
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
import Foundation
@testable import WaterLogged

@Suite(.tags(.importExport))
struct XMLBuilderTests {

	// MARK: - Escaping

	@Test func elementValueIsEscaped() {
		var xml = XMLBuilder()
		xml.element("note", value: "a & b < c > d \" e ' f")
		#expect(xml.result == "<note>a &amp; b &lt; c &gt; d &quot; e &apos; f</note>")
	}

	@Test func attributeValueIsEscaped() {
		var xml = XMLBuilder()
		xml.selfClosing("link", attributes: [("ref", "x & y")])
		#expect(xml.result == "<link ref=\"x &amp; y\"/>")
	}

	@Test func nestingIndentsChildren() {
		var xml = XMLBuilder()
		xml.open("outer")
		xml.element("inner", value: "v")
		xml.close("outer")
		#expect(xml.result == "<outer>\n  <inner>v</inner>\n</outer>")
	}

	// MARK: - Decimal formatting (no C-style formatting)

	@Test("Decimals format without trailing zeros or grouping", arguments: [
		(value: 30.0, expected: "30"),
		(value: 20.5, expected: "20.5"),
		(value: -87.0196, expected: "-87.0196"),
		(value: 0.0, expected: "0"),
		(value: 293.15, expected: "293.15")
	])
	func decimalFormatting(value: Double, expected: String) {
		#expect(XMLBuilder.formatDecimal(value) == expected)
	}

	@Test func decimalUsesPosixSeparatorRegardlessOfLocale() {
		// Must always be a dot, never a locale-specific comma.
		#expect(XMLBuilder.formatDecimal(1234.5).contains(",") == false)
	}

	// MARK: - Date formatting

	@Test func iso8601DateHasDateAndTime() {
		let date = Date(timeIntervalSince1970: 1_750_000_000)
		let formatted = XMLBuilder.formatISO8601Date(date)
		#expect(formatted.contains("T"))
		#expect(formatted.contains(":"))
		#expect(formatted.contains("-"))
	}
}
