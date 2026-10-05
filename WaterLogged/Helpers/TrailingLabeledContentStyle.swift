//
//  TrailingLabeledContentStyle.swift
//  WaterLogged
//
//  Created by John Meyer on 10/5/26.
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

/// Lays out `LabeledContent` the way a grouped form row does: the label on
/// the leading edge and the content pushed to the trailing edge.
///
/// ``TileFormStyle`` applies this to its rows, which no longer get the system
/// form's row layout once the form draws its own sections.
struct TrailingLabeledContentStyle: LabeledContentStyle {
	func makeBody(configuration: Configuration) -> some View {
		HStack {
			configuration.label
			Spacer()
			configuration.content
		}
	}
}

extension LabeledContentStyle where Self == TrailingLabeledContentStyle {
	/// Label leading, content trailing. See ``TrailingLabeledContentStyle``.
	static var trailing: TrailingLabeledContentStyle { TrailingLabeledContentStyle() }
}
