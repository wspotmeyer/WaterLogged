//
//  StatsMediumTile.swift
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

/// A single statistic cell used in the medium widget's grid: an icon, the value,
/// and a caption label.
struct StatsMediumTile: View {
	let label: LocalizedStringKey
	let value: String
	let icon: String

	var body: some View {
		VStack {
			Image(systemName: icon)
				.font(.title2)
				.foregroundStyle(.tint)
			Text(value)
				.font(.title2.bold())
				.fontDesign(.rounded)
				.lineLimit(1)
				.minimumScaleFactor(0.8)
			Text(label)
				.font(.caption2)
				.foregroundStyle(.secondary)
				.lineLimit(1)
		}
		.frame(idealWidth: 120, maxWidth: .infinity, maxHeight: .infinity)
	}
}
