//
//  DetailViews.swift
//  WaterLogged
//
//  Created by John Meyer on 2/23/26.
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

struct DetailColumn<Content: View>: View {
	@ViewBuilder var content: Content

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			content
		}
		.frame(idealWidth: 280, maxWidth: .infinity, alignment: .leading)
	}
}

struct DetailSection<Content: View>: View {
	let title: String
	@ViewBuilder var content: Content

	var body: some View {
		GroupBox {
			content
				.frame(maxWidth: .infinity, alignment: .leading)
		} label: {
			Text(title)
				.font(.title2.bold())
				.padding(.bottom, 4)
		}
		.tileBackgroundStyle()
	}
}

struct DetailRowContent<Content: View>: View {
	@ViewBuilder var content: Content

	var body: some View {
		HStack {
			content
		}
		.font(.subheadline)
	}
}

struct DetailRow: View {
	let label: String
	let value: String

	var body: some View {
		HStack {
			Text(label)
			Spacer()
			Text(value)
				.fontWeight(.medium)
		}
		.font(.subheadline)
	}
}
