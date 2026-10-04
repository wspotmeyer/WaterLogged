//
//  ISO8601DateParser.swift
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

import Foundation

/// Parses the ISO 8601 date-times found in UDDF files and in WaterLogged's own
/// `extras.xml`.
nonisolated enum ISO8601DateParser {
	/// Accepts, in order of preference:
	/// 1. A full internet date-time with a time zone ("2006-04-28T08:15:00Z",
	///    "…+05:00"), which is respected.
	/// 2. A date-time without a time zone ("2006-04-28T08:15:00"), read as local
	///    time. Most UDDF exporters write the dive computer's local time with no
	///    zone, so this keeps the original wall-clock time on display.
	/// 3. "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm" or "yyyy-MM-dd", also local.
	static func date(from string: String) -> Date? {
		let formatter = ISO8601DateFormatter()
		formatter.formatOptions = [.withInternetDateTime]
		if let date = formatter.date(from: string) {
			return date
		}
		formatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
		formatter.timeZone = .current
		if let date = formatter.date(from: string) {
			return date
		}
		let df = DateFormatter()
		df.locale = Locale(identifier: "en_US_POSIX")
		df.timeZone = .current
		for format in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd"] {
			df.dateFormat = format
			if let date = df.date(from: string) {
				return date
			}
		}
		return nil
	}
}
