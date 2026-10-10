//
//  StatsSummaryWidget.swift
//  WaterLoggedWidgets
//
//  Created by John Meyer on 6/28/26.
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

import WidgetKit
import SwiftUI

/// The medium "Dive Stats" widget: a 3×2 grid summarizing the whole log book.
/// Tapping it opens the app on the Statistics view via `widgetURL`.
///
/// Keeps the original widget `kind` so any already-installed instances survive
/// the split into per-metric widgets.
struct StatsSummaryWidget: Widget {
	let kind = "WaterLoggedStatsWidget"

	var body: some WidgetConfiguration {
		StaticConfiguration(kind: kind, provider: StatsProvider()) { entry in
			StatsMediumView(snapshot: entry.snapshot)
				.widgetStatsChrome()
		}
		.configurationDisplayName("Dive Stats")
		.description("Your diving statistics at a glance.")
		.supportedFamilies([.systemMedium])
	}
}

#Preview(as: .systemMedium) {
	StatsSummaryWidget()
} timeline: {
	StatsEntry(date: .now, snapshot: .placeholder)
}
