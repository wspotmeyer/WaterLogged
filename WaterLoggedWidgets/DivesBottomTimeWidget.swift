//
//  DivesBottomTimeWidget.swift
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

/// The small "Dives & Bottom Time" widget: total dives with total bottom time beneath.
/// Tapping it opens the app on the Statistics view via `widgetURL`.
struct DivesBottomTimeWidget: Widget {
	let kind = "WaterLoggedStatsDivesBottomTime"

	var body: some WidgetConfiguration {
		StaticConfiguration(kind: kind, provider: StatsProvider()) { entry in
			StatsSmallDivesBottomTimeView(snapshot: entry.snapshot)
				.widgetStatsChrome()
		}
		.configurationDisplayName("Dives & Bottom Time")
		.description("Your total dives and bottom time at a glance.")
		.supportedFamilies([.systemSmall])
	}
}

#Preview(as: .systemSmall) {
	DivesBottomTimeWidget()
} timeline: {
	StatsEntry(date: .now, snapshot: .placeholder)
}
