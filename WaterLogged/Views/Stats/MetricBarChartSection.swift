//
//  MetricBarChartSection.swift
//  WaterLogged
//
//  Created by John Meyer on 9/13/26.
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

/// One bar of a `MetricBarChartSection`, carrying both metrics so the chart can switch
/// between them without regrouping the dives.
struct StatMetricValue: Identifiable {
	let id: String
	/// The bar's label on the category axis, which may be decorated (a country flag, for example).
	let label: String
	/// Undecorated name used to break ties between bars of equal size.
	let sortName: String
	let diveCount: Int
	let bottomTimeSeconds: Int
	/// Number of distinct trips the group's dives belong to; dives with no trip don't count.
	let tripCount: Int

	var bottomTimeLabel: String {
		let hours = bottomTimeSeconds / 3600
		let minutes = (bottomTimeSeconds % 3600) / 60
		if hours > 0 {
			return "\(hours)h \(minutes)m"
		}
		return "\(minutes)m"
	}
}

/// A horizontal bar chart of dives grouped by some category, with a toggle that switches
/// between dive counts and total bottom time.
struct MetricBarChartSection: View {
	/// Singular name of the grouping, such as "Country"; used for the section title and axis label.
	let category: String
	let values: [StatMetricValue]
	@Binding var metric: StatMetric
	/// Number of bar rows the chart reserves room for. When `nil` the chart grows to fit every
	/// bar; when set, the chart takes a fixed height and scrolls past that many bars, so sections
	/// sitting side by side in a multi-column layout line up regardless of how many bars each has.
	var barCapacity: Int?
	@Environment(\.colorScheme) private var colorScheme

	/// Height of a single bar's row. A per-row height rather than a share of the plot, so bars stay
	/// the same thickness whether a chart has three of them or thirty. Scaled: each row has to hold
	/// a category label stacked above its bar, so the row has to grow with the label's text.
	@ScaledMetric(relativeTo: .caption2) private var rowHeight: CGFloat = 36

	/// Thickness of a bar. The category label sits at the top of each row, inside the plot, so a
	/// bar has to fit beneath its own label rather than fill the row.
	private var barThickness: CGFloat { rowHeight * 0.3 }

	/// Height a category label occupies above its bar, and the gap between the two.
	@ScaledMetric(relativeTo: .caption2) private var labelHeight: CGFloat = 13
	private let labelSpacing: CGFloat = 2

	/// How far to push a bar below the center of its row. Charts centers the bar alone, which
	/// leaves the label stacked above it overhanging the gridline at the top of the row and a gap
	/// at the bottom; shifting the bar down by half the label's height centers the pair instead.
	private var barCenterOffset: CGFloat { (labelHeight + labelSpacing) / 2 }

	var body: some View {
		DetailSection(title: "\(metric.name) by \(category)") {
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
			// A plain ScrollView rather than `chartScrollableAxes(.vertical)`: Charts' own
			// scrolling doesn't lay out a *categorical* axis properly — bars collapse to
			// hairlines and drift out of line with their labels. The value axis scrolls away
			// with the bars as a result, which is acceptable here only because every bar is
			// annotated with its own value.
			ScrollView(.vertical) {
				Chart(sortedValues) { item in
					BarMark(
						x: .value(metric.name, plotValue(for: item)),
						y: .value(category, item.label),
						height: .fixed(barThickness)
					)
					.offset(y: barCenterOffset)
					.foregroundStyle(metric.color(for: colorScheme))
					.clipShape(.rect(cornerRadius: 4))
					// The category name rides on the mark rather than on the y axis. Left to the
					// axis it gets placed a whole row's height away from the bar it belongs to,
					// close enough to the *next* bar to read as if every row were mislabelled.
					.annotation(position: .topLeading, alignment: .leading, spacing: labelSpacing,
								overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
						Text(item.label)
							.font(.caption2)
							.foregroundStyle(.secondary)
							.lineLimit(1)
					}
					.annotation(position: .trailing) {
						Text(barLabel(for: item))
							.font(.caption2)
							.foregroundStyle(.secondary)
							.contentTransition(.numericText())
					}
				}
				// Gridlines only: the category names are drawn on the marks instead.
				.chartYAxis {
					AxisMarks { _ in
						AxisGridLine()
					}
				}
				.chartXAxis {
					AxisMarks(values: .stride(by: axisStride)) { value in
						AxisGridLine()
						AxisValueLabel {
							if let number = value.as(Double.self) {
								axisLabel(for: number)
							}
						}
					}
				}
				.frame(height: contentHeight)
			}
			.frame(height: chartHeight)
			// Nothing to bounce against when the bars already fit.
			.scrollBounceBehavior(.basedOnSize)
			// A chart with every row filtered out reads as broken rather than empty,
			// which happens whenever no dive in this grouping belongs to a trip.
			.overlay {
				if sortedValues.isEmpty {
					Text("No \(metric.name) Recorded")
						.font(.callout)
						.foregroundStyle(.secondary)
				}
			}
			// Bars keep their identity across metrics, so Charts interpolates bar lengths,
			// row order, and axis gridlines.
			.animation(.smooth, value: metric)
		}
	}

	/// Height of the chart itself: a row per bar, so bars and their labels keep their natural
	/// spacing however many there are. The floor leaves room for the empty-state overlay.
	private var contentHeight: CGFloat {
		Swift.max(CGFloat(sortedValues.count) * rowHeight, 100)
	}

	/// Height of the visible window onto the chart. Fixed when a capacity is configured, so
	/// paired sections match and anything past that many bars scrolls; otherwise the same as
	/// ``contentHeight``, which leaves nothing to scroll.
	private var chartHeight: CGFloat {
		guard let barCapacity else { return contentHeight }
		return Swift.max(CGFloat(barCapacity) * rowHeight, 100)
	}

	/// Bars ordered by whichever metric is showing, largest first. Groups whose dives belong
	/// to no trip are dropped from the trips chart rather than drawn as empty bars.
	private var sortedValues: [StatMetricValue] {
		switch metric {
		case .dives:
			values.sorted { ($0.diveCount, $1.sortName) > ($1.diveCount, $0.sortName) }
		case .bottomTime:
			values.sorted { ($0.bottomTimeSeconds, $1.sortName) > ($1.bottomTimeSeconds, $0.sortName) }
		case .trips:
			values.filter { $0.tripCount > 0 }
				.sorted { ($0.tripCount, $1.sortName) > ($1.tripCount, $0.sortName) }
		}
	}

	/// The value plotted on the horizontal axis: a dive count, or bottom time in whichever
	/// time unit keeps the axis labels short for the current data.
	private func plotValue(for item: StatMetricValue) -> Double {
		switch metric {
		case .dives:
			Double(item.diveCount)
		case .bottomTime:
			bottomTimeInHours ? Double(item.bottomTimeSeconds) / 3600 : Double(item.bottomTimeSeconds) / 60
		case .trips:
			Double(item.tripCount)
		}
	}

	private func barLabel(for item: StatMetricValue) -> String {
		switch metric {
		case .dives:
			"\(item.diveCount)"
		case .bottomTime:
			item.bottomTimeLabel
		case .trips:
			"\(item.tripCount)"
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

	/// Bottom time is plotted in hours once any bar passes two hours; below that, minutes read better.
	private var bottomTimeInHours: Bool {
		(values.map(\.bottomTimeSeconds).max() ?? 0) >= 7200
	}

	/// An explicit stride keeps the axis labels on round values, which automatic marks
	/// don't guarantee once the plotted values switch units.
	private var axisStride: Double {
		let largest = sortedValues.map { plotValue(for: $0) }.max() ?? 0
		guard largest > 0 else { return 1 }
		let rough = largest / 4
		let magnitude = pow(10, log10(rough).rounded(.down))
		let normalized = rough / magnitude
		let nice: Double = if normalized <= 1.5 { 1 } else if normalized <= 3 { 2 } else if normalized <= 7 { 5 } else { 10 }
		let step = nice * magnitude
		// Dive and trip counts are whole numbers, so never subdivide below one.
		return metric.isCount ? Swift.max(1, step.rounded()) : step
	}
}

private let previewValues = [
	StatMetricValue(id: "us", label: "🇺🇸 United States", sortName: "United States", diveCount: 12, bottomTimeSeconds: 32_400, tripCount: 3),
	StatMetricValue(id: "eg", label: "🇪🇬 Egypt", sortName: "Egypt", diveCount: 8, bottomTimeSeconds: 19_740, tripCount: 2),
	StatMetricValue(id: "mx", label: "🇲🇽 Mexico", sortName: "Mexico", diveCount: 3, bottomTimeSeconds: 7_020, tripCount: 1),
	// No trip, so this row is absent from the trips chart.
	StatMetricValue(id: "ph", label: "🇵🇭 Philippines", sortName: "Philippines", diveCount: 5, bottomTimeSeconds: 12_600, tripCount: 0)
]

#Preview("Dives") {
	@Previewable @State var metric: StatMetric = .dives
	ScrollView {
		MetricBarChartSection(category: "Country", values: previewValues, metric: $metric)
			.padding()
	}
}

#Preview("Bottom Time") {
	@Previewable @State var metric: StatMetric = .bottomTime
	ScrollView {
		MetricBarChartSection(category: "Country", values: previewValues, metric: $metric)
			.padding()
	}
}

#Preview("Trips") {
	@Previewable @State var metric: StatMetric = .trips
	ScrollView {
		MetricBarChartSection(category: "Country", values: previewValues, metric: $metric)
			.padding()
	}
}

// More bars than any phone screen can show at once, which is the case a capacity exists for.
#Preview("Many Bars") {
	@Previewable @State var metric: StatMetric = .dives
	// Long labels on purpose: the width of a category label affects how the axis lays out, so
	// short placeholder names hide problems that real region and buddy names expose.
	let names = ["Cozumel", "Wakatobi", "Kavieng", "Florida", "Raja Ampat", "Cocos Island",
				 "Grand Cayman", "Great Barrier Reef", "Galápagos Islands", "Palau", "Bonaire",
				 "Komodo", "Similan Islands", "Socorro", "Maldives", "Red Sea", "Truk Lagoon", "Fiji"]
	let many = names.enumerated().map { index, name in
		StatMetricValue(id: name, label: name, sortName: name,
						diveCount: 160 - index * 7, bottomTimeSeconds: (160 - index * 7) * 2_700,
						tripCount: index % 4)
	}
	ScrollView {
		MetricBarChartSection(category: "Site", values: many, metric: $metric, barCapacity: 8)
			.padding()
	}
}

// Two sections with different bar counts, which is where a capacity earns its keep: both come
// out the same height and the fuller one scrolls. Forced wide, since the sections only pair up
// on a wide canvas.
#Preview("Matched Heights") {
	@Previewable @State var countryMetric: StatMetric = .dives
	@Previewable @State var regionMetric: StatMetric = .dives
	ScrollView {
		HStack(alignment: .top, spacing: 16) {
			MetricBarChartSection(category: "Country", values: previewValues, metric: $countryMetric, barCapacity: 3)
			MetricBarChartSection(category: "Region", values: Array(previewValues.prefix(2)), metric: $regionMetric, barCapacity: 3)
		}
		.padding()
	}
	.frame(minWidth: 900, minHeight: 500)
}
