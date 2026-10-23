//
//  YearlyStatValue.swift
//  WaterLogged
//
//  Created by John Meyer on 10/23/26.
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

/// One bar of a ``MetricYearChartSection``: a calendar year's totals for every metric, so the
/// chart can switch between them without regrouping the dives.
struct YearlyStatValue: Identifiable {
	/// The first moment of the year.
	let year: Date
	let value: StatMetricValue

	var id: Date { year }

	/// The year as it's labelled, such as "2024".
	var yearLabel: String { value.label }

	init(year: Date, dives: [Dive]) {
		self.year = year
		let label = year.formatted(.dateTime.year())
		value = StatMetricValue(
			id: label,
			label: label,
			sortName: label,
			diveCount: dives.count,
			bottomTimeSeconds: dives.reduce(0) { $0 + $1.durationSeconds },
			tripCount: Set(dives.compactMap { $0.trip?.externalId }).count
		)
	}

	/// The year's total for a metric: a dive or trip count, or bottom time in seconds.
	func value(for metric: StatMetric) -> Int {
		switch metric {
		case .dives: value.diveCount
		case .bottomTime: value.bottomTimeSeconds
		case .trips: value.tripCount
		}
	}

	/// One value per year that has dives, oldest first. Years without dives are left out rather
	/// than drawn as empty bars. A trip that runs over New Year counts toward both years.
	static func grouped(_ dives: [Dive], calendar: Calendar = .current) -> [YearlyStatValue] {
		var divesByYear: [Date: [Dive]] = [:]
		for dive in dives {
			guard let year = calendar.dateInterval(of: .year, for: dive.date)?.start else { continue }
			divesByYear[year, default: []].append(dive)
		}
		return divesByYear
			.map { YearlyStatValue(year: $0.key, dives: $0.value) }
			.sorted { $0.year < $1.year }
	}
}
