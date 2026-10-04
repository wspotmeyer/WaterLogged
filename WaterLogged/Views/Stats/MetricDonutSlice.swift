//
//  MetricDonutSlice.swift
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

import Foundation

/// One slice of a ``MetricDonutChart``: a group's totals for every metric, plus the
/// ``ChartCategoryPalette`` slot that colors it.
struct MetricDonutSlice: Identifiable {
	/// Identifier of the slice that collects the groups past the palette's last slot. Not a
	/// plausible group name, so a gas mix that happens to be called "Other" keeps its own slice.
	static let otherID = "\u{0}other"

	let value: StatMetricValue
	/// Palette slot, or `nil` for the "Other" slice.
	let paletteSlot: Int?

	var id: String { value.id }

	init(id: String, label: String, dives: [Dive], paletteSlot: Int?) {
		value = StatMetricValue(
			id: id,
			label: label,
			sortName: label,
			diveCount: dives.count,
			bottomTimeSeconds: dives.reduce(0) { $0 + $1.durationSeconds },
			tripCount: Set(dives.compactMap { $0.trip?.externalId }).count
		)
		self.paletteSlot = paletteSlot
	}

	/// The slice's size for a metric: a dive or trip count, or bottom time in seconds.
	func value(for metric: StatMetric) -> Int {
		switch metric {
		case .dives: value.diveCount
		case .bottomTime: value.bottomTimeSeconds
		case .trips: value.tripCount
		}
	}

	/// The slice's value as shown in the legend and the donut's hole, such as "3h 20m".
	func valueLabel(for metric: StatMetric) -> String {
		switch metric {
		case .dives: "\(value.diveCount)"
		case .bottomTime: value.bottomTimeLabel
		case .trips: "\(value.tripCount)"
		}
	}

	/// The slice's share of the whole ring for a metric, from 0 to 1. For gas mixes this is a
	/// share of the ring rather than of all dives, since a multi-gas dive counts toward each mix.
	func share(of slices: [MetricDonutSlice], for metric: StatMetric) -> Double {
		let total = slices.reduce(0) { $0 + $1.value(for: metric) }
		guard total > 0 else { return 0 }
		return Double(value(for: metric)) / Double(total)
	}

	/// The slice drawn at a point round the ring, measured as the running total of `metric`
	/// clockwise from 12 o'clock — the form `chartAngleSelection` reports it in.
	static func slice(
		atCumulativeValue target: Double,
		in slices: [MetricDonutSlice],
		metric: StatMetric
	) -> MetricDonutSlice? {
		guard target >= 0 else { return nil }
		var runningTotal = 0.0
		for slice in slices {
			runningTotal += Double(slice.value(for: metric))
			if target <= runningTotal {
				return slice
			}
		}
		return nil
	}

	/// Slices for groups with no natural order, keyed by label. The groups with the most dives
	/// take the palette's slots in turn; if there are more groups than slots, the smallest fold
	/// into a single "Other" slice so no hue is ever reused.
	///
	/// Ranked by dive count whichever metric is showing, so a slice keeps its color — and its
	/// place round the ring — when the metric changes.
	static func ranked(_ divesByGroup: [String: [Dive]]) -> [MetricDonutSlice] {
		let ordered = divesByGroup.sorted { ($0.value.count, $1.key) > ($1.value.count, $0.key) }
		guard ordered.count > ChartCategoryPalette.slotCount else {
			return ordered.enumerated().map { index, group in
				MetricDonutSlice(id: group.key, label: group.key, dives: group.value, paletteSlot: index)
			}
		}
		let namedCount = ChartCategoryPalette.slotCount
		let named = ordered.prefix(namedCount).enumerated().map { index, group in
			MetricDonutSlice(id: group.key, label: group.key, dives: group.value, paletteSlot: index)
		}
		// A dive can belong to several of the folded groups (two gas mixes, say); count it once.
		var seen = Set<String>()
		let otherDives = ordered.dropFirst(namedCount)
			.flatMap(\.value)
			.filter { seen.insert($0.externalId).inserted }
		let other = MetricDonutSlice(
			id: otherID,
			label: String(localized: "Other"),
			dives: otherDives,
			paletteSlot: nil
		)
		return named + [other]
	}
}
