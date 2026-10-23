//
//  MetricYearChartSection.swift
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

import SwiftUI
import Charts

/// A column chart of dives, bottom time, or trips per calendar year, with the same metric picker
/// as the other statistics sections.
struct MetricYearChartSection: View {
	let years: [YearlyStatValue]
	@Binding var metric: StatMetric
	@Environment(\.colorScheme) private var colorScheme

	var body: some View {
		DetailSection(title: "\(metric.name) Per Year") {
			HStack {
				Spacer()
				Picker("Metric", selection: $metric) {
					ForEach(StatMetric.allCases) { option in
						Text(option.pickerTitle).tag(option)
					}
				}
				.pickerStyle(.segmented)
				.labelsHidden()
				// Segmented pickers fill their width by default; hug the labels instead.
				.fixedSize()
			}
			.padding(.bottom, 8)
			// Every year stays on the axis whichever metric is showing, so the columns don't
			// shift sideways when the picker changes; a year with no trips just has no column.
			Chart(years) { item in
				BarMark(
					x: .value("Year", item.year, unit: .year),
					y: .value(metric.name, plotValue(for: item))
				)
				// Same color as this metric in the other sections, so a quantity looks the same
				// wherever it's charted.
				.foregroundStyle(metric.color(for: colorScheme))
				.clipShape(.rect(cornerRadius: 4))
				.annotation(position: .top) {
					if item.value(for: metric) > 0 {
						Text(barLabel(for: item))
							.font(.caption2)
							.foregroundStyle(.secondary)
							.contentTransition(.numericText())
					}
				}
			}
			.chartXAxis {
				AxisMarks(values: .stride(by: .year)) { _ in
					AxisGridLine()
					AxisValueLabel(format: .dateTime.year(), centered: true, collisionResolution: .greedy, orientation: .verticalReversed)
						.font(.caption2.monospacedDigit())
				}
			}
			.chartYAxis {
				AxisMarks(values: .stride(by: axisStride)) { value in
					AxisGridLine()
					AxisValueLabel {
						if let number = value.as(Double.self) {
							axisLabel(for: number)
						}
					}
				}
			}
			// Grows past its minimum when paired with the water and gas section, so the two
			// sections sitting side by side come out the same height.
			.frame(minHeight: 220, idealHeight: 220, maxHeight: .infinity)
			// Every year can come up empty for trips, when no dive belongs to one.
			.overlay {
				if !years.contains(where: { $0.value(for: metric) > 0 }) {
					Text("No \(metric.name) Recorded")
						.font(.callout)
						.foregroundStyle(.secondary)
				}
			}
			// Left to itself, Swift Charts reads many years as ranges of years with their plotted
			// values. So VoiceOver gets one element with a summary, and Audio Graph the values.
			.accessibilityElement(children: .ignore)
			.accessibilityLabel(descriptor.title)
			.accessibilityValue(descriptor.summary)
			.accessibilityChartDescriptor(descriptor)
			// Columns keep their identity across metrics, so Charts interpolates their heights
			// and the axis gridlines.
			.animation(.smooth, value: metric)
		}
	}

	private var descriptor: DivesPerYearChartDescriptor {
		DivesPerYearChartDescriptor(years: years, metric: metric)
	}

	/// The value plotted on the vertical axis: a count, or bottom time in whichever time unit
	/// keeps the axis labels short for the current data.
	private func plotValue(for item: YearlyStatValue) -> Double {
		switch metric {
		case .dives, .trips:
			Double(item.value(for: metric))
		case .bottomTime:
			bottomTimeInHours ? Double(item.value.bottomTimeSeconds) / 3600 : Double(item.value.bottomTimeSeconds) / 60
		}
	}

	/// The number above a column. Bottom time is rounded to whole hours once the chart is in
	/// hours, since narrow year columns have no room for "123h 45m".
	private func barLabel(for item: YearlyStatValue) -> String {
		switch metric {
		case .dives, .trips:
			"\(item.value(for: metric))"
		case .bottomTime:
			if bottomTimeInHours {
				"\((Double(item.value.bottomTimeSeconds) / 3600).formatted(.number.precision(.fractionLength(0))))h"
			} else {
				"\(item.value.bottomTimeSeconds / 60)m"
			}
		}
	}

	@ViewBuilder
	private func axisLabel(for value: Double) -> some View {
		switch metric {
		case .dives, .trips:
			Text(value, format: .number.precision(.fractionLength(0)))
		case .bottomTime:
			if bottomTimeInHours {
				Text("\(value, format: .number.precision(.fractionLength(0...1)))h")
			} else {
				Text("\(value, format: .number.precision(.fractionLength(0)))m")
			}
		}
	}

	/// Bottom time is plotted in hours once any year passes two hours; below that, minutes read better.
	private var bottomTimeInHours: Bool {
		(years.map(\.value.bottomTimeSeconds).max() ?? 0) >= 7200
	}

	private var axisStride: Double {
		metric.axisStride(forLargest: years.map { plotValue(for: $0) }.max() ?? 0)
	}
}

#Preview {
	@Previewable @State var metric: StatMetric = .dives
	let calendar = Calendar.current
	let trip = Trip(name: "Cozumel", startDate: .distantPast, endDate: .distantPast)
	let years = (2018...2026).map { year in
		let start = calendar.date(from: DateComponents(year: year)) ?? .now
		let dives = (0..<((year * 7) % 23 + 2)).map { _ in Dive(date: start, durationSeconds: 2_700) }
		if year.isMultiple(of: 2) {
			dives.forEach { $0.trip = trip }
		}
		return YearlyStatValue(year: start, dives: dives)
	}
	ScrollView {
		MetricYearChartSection(years: years, metric: $metric)
			.padding()
	}
}
