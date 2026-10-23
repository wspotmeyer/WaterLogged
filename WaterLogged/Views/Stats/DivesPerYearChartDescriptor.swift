//
//  DivesPerYearChartDescriptor.swift
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

import Accessibility
import SwiftUI

/// Describes the Dives Per Year chart to VoiceOver and its Audio Graph.
///
/// With many years of bars, Swift Charts groups them into ranges of years for VoiceOver and stops
/// reading each bar's own label. So the chart reads as one element with `summary` as its value,
/// and this hands Audio Graph the year-by-year counts.
struct DivesPerYearChartDescriptor: AXChartDescriptorRepresentable {
	/// Each year with dives, oldest first, as its display label such as "2024".
	let years: [String]
	/// The number of dives in each year, matching `years` index for index.
	let counts: [Int]

	/// A one-line description of the chart, such as "From 1995 to 2026, most dives in 2008: 55
	/// dives", which VoiceOver reads as the chart's value.
	var summary: String {
		guard let first = years.first, let last = years.last,
			  let busiest = zip(years, counts).max(by: { $0.1 < $1.1 }) else {
			return String(localized: "No dives")
		}
		return String(localized: "From \(first) to \(last), most dives in \(busiest.0): \(Self.diveCount(busiest.1))")
	}

	func makeChartDescriptor() -> AXChartDescriptor {
		let xAxis = AXCategoricalDataAxisDescriptor(
			title: String(localized: "Year"),
			categoryOrder: years
		)

		let yAxis = AXNumericDataAxisDescriptor(
			title: String(localized: "Dives"),
			range: 0...Double(max(counts.max() ?? 0, 1)),
			gridlinePositions: []
		) { value in
			Self.diveCount(Int(value))
		}

		let series = AXDataSeriesDescriptor(
			name: String(localized: "Dives"),
			isContinuous: false,
			dataPoints: zip(years, counts).map { AXDataPoint(x: $0, y: Double($1)) }
		)

		return AXChartDescriptor(
			title: String(localized: "Dives per year"),
			summary: summary,
			xAxis: xAxis,
			yAxis: yAxis,
			additionalAxes: [],
			series: [series]
		)
	}

	/// A dive count with the right form of "dive", such as "1 dive" or "55 dives".
	private static func diveCount(_ count: Int) -> String {
		String(AttributedString(localized: "^[\(count) dive](inflect: true)").characters)
	}
}
