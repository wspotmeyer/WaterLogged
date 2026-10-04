//
//  MetricDonutChart.swift
//  WaterLogged
//
//  Created by John Meyer on 9/26/26.
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

/// A donut chart of dives grouped by some category, showing whichever metric the
/// enclosing ``MetricDonutChartSection`` has selected, with a legend that names every
/// slice and its value. Hovering over a slice — or touching it — names it and its value
/// in the donut's hole.
struct MetricDonutChart: View {
	/// Name of the grouping, such as "Water Type"; shown above the donut.
	let title: String
	/// Slices in ring order. Kept in palette order rather than sorted by value, so the
	/// neighbors round the ring are always the pairs the palette was validated for.
	let slices: [MetricDonutSlice]
	let metric: StatMetric
	@Environment(\.colorScheme) private var colorScheme

	/// Where the pointer sits round the ring, as a running total of the metric; `nil` when
	/// the pointer is off the ring.
	@State private var hoverValue: Double?
	/// Where a touch or click sits round the ring, as reported by `chartAngleSelection`.
	@State private var selectedAngleValue: Int?
	/// The chart's size, needed to turn a hover location into a point round the ring.
	@State private var chartSize: CGSize = .zero

	/// Height of the chart; the donut's diameter unless the column is narrower.
	private let donutHeight: CGFloat = 150
	/// The hole's share of the donut's diameter.
	private let innerRadiusRatio: CGFloat = 0.6

	/// Height of one legend row. The legend reserves room for the most rows a chart can
	/// have, so the section doesn't change height as a metric filters slices out.
	@ScaledMetric(relativeTo: .caption) private var legendRowHeight: CGFloat = 18
	private static let maxLegendRows = ChartCategoryPalette.slotCount + 1

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text(title)
				.font(.headline)
				.frame(maxWidth: .infinity)
			Chart(visibleSlices) { slice in
				SectorMark(
					angle: .value(metric.name, slice.value(for: metric)),
					innerRadius: .ratio(innerRadiusRatio),
					// A gap between neighboring slices, so colors never touch.
					angularInset: 1
				)
				.cornerRadius(2)
				.foregroundStyle(ChartCategoryPalette.color(slot: slice.paletteSlot, for: colorScheme))
				// Recede the rest of the ring while one slice is highlighted.
				.opacity(highlightedSlice == nil || highlightedSlice?.id == slice.id ? 1 : 0.4)
				.accessibilityLabel(slice.value.label)
				.accessibilityValue(slice.valueLabel(for: metric))
			}
			.chartAngleSelection(value: $selectedAngleValue)
			.frame(height: donutHeight)
			.contentShape(.rect)
			.onGeometryChange(for: CGSize.self) { $0.size } action: { chartSize = $0 }
			.onContinuousHover { phase in
				switch phase {
				case .active(let location):
					hoverValue = ringValue(at: location)
				case .ended:
					hoverValue = nil
				}
			}
			.overlay {
				if visibleSlices.isEmpty {
					// An empty ring reads as broken rather than empty, which happens whenever
					// no dive in this grouping belongs to a trip.
					Text("No \(metric.name) Recorded")
						.font(.callout)
						.foregroundStyle(.secondary)
						.multilineTextAlignment(.center)
				} else if let highlightedSlice {
					VStack(spacing: 2) {
						Text(highlightedSlice.value.label)
							.font(.caption)
							.foregroundStyle(.secondary)
							.lineLimit(2)
						Text(highlightedSlice.valueLabel(for: metric))
							.font(.headline)
							.monospacedDigit()
							.lineLimit(1)
						// A tenth of a percent at most, so a sliver still reads as more than 0%.
						Text(
							highlightedSlice.share(of: visibleSlices, for: metric),
							format: .percent.precision(.fractionLength(0...1))
						)
						.font(.caption)
						.foregroundStyle(.secondary)
						.monospacedDigit()
						.lineLimit(1)
					}
					.multilineTextAlignment(.center)
					.minimumScaleFactor(0.7)
					// Keep the text inside the hole, clear of the ring.
					.frame(maxWidth: holeDiameter * 0.85, maxHeight: holeDiameter * 0.85)
					// Decoration over the chart; let hovers and touches through to it.
					.allowsHitTesting(false)
				}
			}
			// The legend names every slice beside its color, so no slice is identified by
			// color alone. A grid rather than full-width rows: each column hugs its widest
			// entry, keeping every value close to its label, and the values still line up.
			Grid(alignment: .leading, horizontalSpacing: 6, verticalSpacing: 4) {
				ForEach(visibleSlices) { slice in
					GridRow {
						Circle()
							.fill(ChartCategoryPalette.color(slot: slice.paletteSlot, for: colorScheme))
							.frame(width: 8, height: 8)
						Text(slice.value.label)
							.foregroundStyle(.secondary)
							.lineLimit(1)
						Text(slice.valueLabel(for: metric))
							.monospacedDigit()
							.contentTransition(.numericText())
							.gridColumnAlignment(.trailing)
							.padding(.leading, 6)
					}
					.font(.caption)
					.accessibilityElement(children: .combine)
				}
			}
			// Centered under the donut, with room reserved for the most rows a legend can have.
			.frame(maxWidth: .infinity, minHeight: legendRowHeight * CGFloat(Self.maxLegendRows), alignment: .top)
		}
		// Slices keep their identity across metrics, so Charts interpolates their angles.
		.animation(.smooth, value: metric)
	}

	/// Slices with something to show for the current metric. Groups whose dives belong to
	/// no trip are dropped from the trips ring rather than drawn as zero-width slices.
	private var visibleSlices: [MetricDonutSlice] {
		slices.filter { $0.value(for: metric) > 0 }
	}

	/// Sum of the current metric round the whole ring.
	private var total: Int {
		visibleSlices.reduce(0) { $0 + $1.value(for: metric) }
	}

	/// The slice under the pointer, or failing that under a touch or click.
	private var highlightedSlice: MetricDonutSlice? {
		guard let target = hoverValue ?? selectedAngleValue.map(Double.init) else { return nil }
		return MetricDonutSlice.slice(atCumulativeValue: target, in: visibleSlices, metric: metric)
	}

	/// Diameter of the hole: the donut fills the shorter side of the chart.
	private var holeDiameter: CGFloat {
		min(chartSize.width, chartSize.height) * innerRadiusRatio
	}

	/// Converts a hover location to a point round the ring, in the running-total form that
	/// `chartAngleSelection` also reports, so both can be looked up the same way. `nil`
	/// when the pointer is in the hole or outside the ring.
	private func ringValue(at location: CGPoint) -> Double? {
		let outerRadius = min(chartSize.width, chartSize.height) / 2
		let dx = location.x - chartSize.width / 2
		let dy = location.y - chartSize.height / 2
		let distance = (dx * dx + dy * dy).squareRoot()
		guard outerRadius > 0, distance <= outerRadius, distance >= outerRadius * innerRadiusRatio else {
			return nil
		}
		// Clockwise from 12 o'clock, the way Charts lays out sectors.
		var angle = atan2(dx, -dy)
		if angle < 0 {
			angle += 2 * .pi
		}
		return angle / (2 * .pi) * Double(total)
	}
}
