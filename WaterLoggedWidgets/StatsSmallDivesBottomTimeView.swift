//
//  StatsSmallDivesBottomTimeView.swift
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

import SwiftUI

/// The small widget: a hero "Total Dives" count with the deepest dive beneath.
struct StatsSmallDivesBottomTimeView: View {
	let snapshot: StatsSnapshot

	var body: some View {
		VStack(alignment: .leading) {
			StatsSmallTile(label: "Total Dives", value: snapshot.totalDives.formatted(), icon: "number")
			Spacer()
			StatsSmallTile(label: "Bottom Time", value: snapshot.totalBottomTimeDisplay, icon: "clock.fill")
		}
		.frame(maxWidth: .infinity)
	}
}
