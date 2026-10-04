//
//  StatsSmallTile.swift
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

/// A single statistic cell used in the small widget's grid: an icon, the value,
/// and a caption label.
struct StatsSmallTile: View {
	let label: LocalizedStringKey
	let value: String
	let icon: String

	var body: some View {
		HStack {
			Image(systemName: icon)
				.font(.title)
				.foregroundStyle(.tint)
				.frame(maxWidth: 35)
			Spacer()
			VStack {
				Text(value)
					.font(.largeTitle.weight(.bold))
					.fontDesign(.rounded)
					.lineLimit(1)
					.minimumScaleFactor(0.8)
				Text(label)
					.font(.caption2)
					.foregroundStyle(.secondary)
					.lineLimit(2)
			}
			.frame(maxWidth: .infinity)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.padding(8)
	}
}
