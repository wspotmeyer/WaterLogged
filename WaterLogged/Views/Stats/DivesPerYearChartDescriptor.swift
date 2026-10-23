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

/// Describes the Dives Per Year chart to VoiceOver and its Audio Graph, for whichever metric
/// the chart is showing.
///
/// With many years of bars, Swift Charts groups them into ranges of years for VoiceOver and stops
/// reading each bar's own label. So the chart reads as one element with `summary` as its value,
/// and this hands Audio Graph the year-by-year values.
struct DivesPerYearChartDescriptor: AXChartDescriptorRepresentable {
	/// Each year with dives, oldest first.
	let years: [YearlyStatValue]
	let metric: StatMetric

	/// The chart's title, such as "Bottom time per year".
	var title: String {
		switch metric {
		case .dives: String(localized: "Dives per year")
		case .bottomTime: String(localized: "Bottom time per year")
		case .trips: String(localized: "Trips per year")
		}
	}

	/// A one-line description of the chart, such as "From 1995 to 2026, most dives in 2008: 55
	/// dives", which VoiceOver reads as the chart's value.
	var summary: String {
		guard let first = years.first?.yearLabel, let last = years.last?.yearLabel,
			  let busiest = years.max(by: { $0.value(for: metric) < $1.value(for: metric) }),
			  busiest.value(for: metric) > 0 else {
			return switch metric {
			case .dives: String(localized: "No dives")
			case .bottomTime: String(localized: "No bottom time")
			case .trips: String(localized: "No trips")
			}
		}
		let year = busiest.yearLabel
		let amount = Self.spokenValue(busiest.value(for: metric), for: metric)
		return switch metric {
		case .dives: String(localized: "From \(first) to \(last), most dives in \(year): \(amount)")
		case .bottomTime: String(localized: "From \(first) to \(last), most bottom time in \(year): \(amount)")
		case .trips: String(localized: "From \(first) to \(last), most trips in \(year): \(amount)")
		}
	}

	func makeChartDescriptor() -> AXChartDescriptor {
		let metric = metric
		let xAxis = AXCategoricalDataAxisDescriptor(
			title: String(localized: "Year"),
			categoryOrder: years.map(\.yearLabel)
		)

		// Bottom time is plotted in hours, so the values stay readable on Audio Graph's axis.
		let plotted = years.map { Self.plotValue($0.value(for: metric), for: metric) }
		let yAxis = AXNumericDataAxisDescriptor(
			title: metric.name,
			range: 0...max(plotted.max() ?? 0, 1),
			gridlinePositions: []
		) { value in
			Self.spokenValue(Self.metricValue(fromPlotted: value, for: metric), for: metric)
		}

		let series = AXDataSeriesDescriptor(
			name: metric.name,
			isContinuous: false,
			dataPoints: zip(years, plotted).map { AXDataPoint(x: $0.yearLabel, y: $1) }
		)

		return AXChartDescriptor(
			title: title,
			summary: summary,
			xAxis: xAxis,
			yAxis: yAxis,
			additionalAxes: [],
			series: [series]
		)
	}

	/// A metric's value as Audio Graph plots it: a count, or bottom time in hours.
	private static func plotValue(_ value: Int, for metric: StatMetric) -> Double {
		metric == .bottomTime ? Double(value) / 3600 : Double(value)
	}

	/// The inverse of ``plotValue(_:for:)``: a count, or bottom time in seconds.
	private static func metricValue(fromPlotted value: Double, for metric: StatMetric) -> Int {
		metric == .bottomTime ? Int((value * 3600).rounded()) : Int(value.rounded())
	}

	/// A value with its unit, such as "1 dive", "3 trips", or "40 hours, 5 minutes".
	static func spokenValue(_ value: Int, for metric: StatMetric) -> String {
		switch metric {
		case .dives:
			String(AttributedString(localized: "^[\(value) dive](inflect: true)").characters)
		case .bottomTime:
			Duration.seconds(value).formatted(.units(allowed: [.hours, .minutes], width: .wide))
		case .trips:
			String(AttributedString(localized: "^[\(value) trip](inflect: true)").characters)
		}
	}
}
