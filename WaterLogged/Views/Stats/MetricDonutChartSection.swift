//
//  MetricDonutChartSection.swift
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

/// Donut charts of dives by water type and by gas mix, sharing one metric picker so the
/// two rings always show the same quantity.
struct MetricDonutChartSection: View {
	let waterTypeSlices: [MetricDonutSlice]
	let gasMixSlices: [MetricDonutSlice]
	@Binding var metric: StatMetric

	var body: some View {
		DetailSection(title: "\(metric.name) by Water Type & Gas Mix") {
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
			HStack(alignment: .top, spacing: 16) {
				MetricDonutChart(title: "Water Type", slices: waterTypeSlices, metric: metric)
					.frame(maxWidth: .infinity)
#if os(macOS)
				// Mac windows run wide enough that the two legends' values would otherwise sit
				// almost against each other; a gutter keeps the columns reading separately.
				Spacer()
					.frame(width: 32)
#endif
				MetricDonutChart(title: "Gas Mix", slices: gasMixSlices, metric: metric)
					.frame(maxWidth: .infinity)
			}
			// Nothing on the rings themselves says they respond, so point it out.
			Text(Self.interactionHint)
				.font(.footnote)
				.foregroundStyle(.secondary)
				.frame(maxWidth: .infinity)
				.multilineTextAlignment(.center)
				.padding(.top, 8)
		}
	}

	/// Mac users hover with the pointer; everywhere else a touch is the one gesture every device
	/// has, even though an iPad with a pointer can hover too.
	private static var interactionHint: LocalizedStringKey {
#if os(macOS)
		"Hover over a slice to see its details."
#else
		"Touch a slice to see its details."
#endif
	}
}

#Preview {
	@Previewable @State var metric: StatMetric = .dives
	let salt = (0..<14).map { _ in Dive(durationSeconds: 2_700) }
	let fresh = (0..<4).map { _ in Dive(durationSeconds: 3_600) }
	let brackish = [Dive(durationSeconds: 1_800)]
	let gasMixes = MetricDonutSlice.ranked([
		"Air": Array(salt.prefix(8)) + fresh,
		"EAN32": Array(salt.suffix(6)),
		"EAN36": brackish,
		"Trimix 21/35": [salt[0]],
		"EAN50": [salt[0]],
		"Oxygen": [salt[1]]
	])
	ScrollView {
		MetricDonutChartSection(
			waterTypeSlices: [
				MetricDonutSlice(id: "salt", label: "Salt", dives: salt, paletteSlot: 0),
				MetricDonutSlice(id: "brackish", label: "Brackish", dives: brackish, paletteSlot: 1),
				MetricDonutSlice(id: "fresh", label: "Fresh", dives: fresh, paletteSlot: 2)
			],
			gasMixSlices: gasMixes,
			metric: $metric
		)
		.padding()
	}
}
