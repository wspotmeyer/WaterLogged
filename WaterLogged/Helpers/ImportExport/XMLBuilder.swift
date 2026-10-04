//
//  XMLBuilder.swift
//  WaterLogged
//
//  Created by John Meyer on 4/26/26.
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

/// Builds well-formed, indented XML output using an array of lines for efficient concatenation.
struct XMLBuilder {
	private var lines: [String] = []
	private var depth = 0

	var result: String {
		lines.joined(separator: "\n")
	}

	mutating func rawLine(_ text: String) {
		lines.append(text)
	}

	mutating func open(_ tag: String, attributes: [(String, String)] = []) {
		lines.append(indent + "<" + tag + formatAttributes(attributes) + ">")
		depth += 1
	}

	mutating func close(_ tag: String) {
		depth -= 1
		lines.append(indent + "</" + tag + ">")
	}

	mutating func element(_ tag: String, value: String, attributes: [(String, String)] = []) {
		lines.append(indent + "<" + tag + formatAttributes(attributes) + ">"
					 + escapeXML(value) + "</" + tag + ">")
	}

	mutating func selfClosing(_ tag: String, attributes: [(String, String)]) {
		lines.append(indent + "<" + tag + formatAttributes(attributes) + "/>")
	}

	private var indent: String {
		String(repeating: "  ", count: depth)
	}

	private func formatAttributes(_ attrs: [(String, String)]) -> String {
		attrs.map { " \($0.0)=\"\(escapeXML($0.1))\"" }.joined()
	}

	private func escapeXML(_ text: String) -> String {
		text.replacing("&", with: "&amp;")
			.replacing("<", with: "&lt;")
			.replacing(">", with: "&gt;")
			.replacing("\"", with: "&quot;")
			.replacing("'", with: "&apos;")
	}

	// MARK: - Shared Formatting Utilities

	private static let decimalFormatter: NumberFormatter = {
		let formatter = NumberFormatter()
		formatter.numberStyle = .decimal
		formatter.maximumFractionDigits = 6
		formatter.minimumFractionDigits = 0
		formatter.usesGroupingSeparator = false
		formatter.locale = Locale(identifier: "en_US_POSIX")
		return formatter
	}()

	static func formatDecimal(_ value: Double) -> String {
		decimalFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
	}

	static func formatISO8601Date(_ date: Date) -> String {
		let formatter = ISO8601DateFormatter()
		formatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
		formatter.timeZone = .current
		return formatter.string(from: date)
	}

	static func exportDateStamp() -> String {
		Date.now.formatted(
			Date.ISO8601FormatStyle(timeZone: .current)
				.year()
				.month()
				.day()
				.dateSeparator(.dash)
		)
	}
}
