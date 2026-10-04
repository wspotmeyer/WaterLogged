//
//  ListRowLabelStyle.swift
//  WaterLogged
//
//  Created by John Meyer on 5/14/26.
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

/// A compact label style used for icon + text pairs in list row metadata.
struct ListRowLabelStyle: LabelStyle {
	func makeBody(configuration: Configuration) -> some View {
		HStack(spacing: 3) {
			configuration.icon
			configuration.title
		}
	}
}

extension LabelStyle where Self == ListRowLabelStyle {
	static var listRow: ListRowLabelStyle { ListRowLabelStyle() }
}
