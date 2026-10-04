//
//  StatsProvider.swift
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

/// A single timeline entry carrying the latest statistics snapshot.
struct StatsEntry: TimelineEntry {
	let date: Date
	let snapshot: StatsSnapshot
}

/// Supplies timeline entries from the shared App Group snapshot the app writes.
///
/// The timeline is a single entry with a `.never` refresh policy: the app pushes
/// updates by calling `WidgetCenter.shared.reloadAllTimelines()` from
/// `StatsWidgetCoordinator` whenever the logbook changes, so the widget never
/// needs to poll. The same provider backs every stats widget, since they all
/// render from the one shared snapshot.
struct StatsProvider: TimelineProvider {
	func placeholder(in context: Context) -> StatsEntry {
		StatsEntry(date: .now, snapshot: .placeholder)
	}

	func getSnapshot(in context: Context, completion: @escaping (StatsEntry) -> Void) {
		completion(StatsEntry(date: .now, snapshot: .load()))
	}

	func getTimeline(in context: Context, completion: @escaping (Timeline<StatsEntry>) -> Void) {
		let entry = StatsEntry(date: .now, snapshot: .load())
		completion(Timeline(entries: [entry], policy: .never))
	}
}
