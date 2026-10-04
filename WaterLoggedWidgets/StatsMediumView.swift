//
//  StatsMediumView.swift
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

/// The medium widget: a 3×2 grid of summary statistics mirroring the in-app
/// Statistics summary grid.
///
/// Two rows that each expand to fill half the available height (so the tiles
/// spread across the whole widget rather than bunching in the middle), with
/// vertical padding for breathing room.
struct StatsMediumView: View {
	let snapshot: StatsSnapshot

	var body: some View {
		VStack {
			StatsMediumRow {
				StatsMediumTile(label: "Dives", value: snapshot.totalDives.formatted(), icon: "number")
				StatsMediumTile(label: "Bottom Time", value: snapshot.totalBottomTimeDisplay, icon: "clock.fill")
				StatsMediumTile(label: "Max Depth", value: snapshot.deepestDepthDisplay, icon: "arrow.down.to.line")
			}
			Spacer()
			StatsMediumRow {
				StatsMediumTile(label: "Countries", value: snapshot.countriesVisited.formatted(), icon: "globe")
				StatsMediumTile(label: "Dive Sites", value: snapshot.diveSitesVisited.formatted(), icon: "mappin.and.ellipse")
				StatsMediumTile(label: "Trips", value: snapshot.tripsVisited.formatted(), icon: "airplane.path.dotted")
			}
		}
		.padding(.vertical, 16)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}
}
