//
//  StarRatingView.swift
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

struct StarRatingView: View {
	let rating: Int
	var interactive: Bool = false
	var onRate: ((Int) -> Void)?

	var body: some View {
		HStack(spacing: 3) {
			if interactive && rating > 0 {
				Button {
					onRate?(0)
				} label: {
					Image(systemName: "xmark.circle.fill")
						.foregroundStyle(.secondary)
						.font(.caption)
				}
				.buttonStyle(.plain)
				.padding(.trailing, 10)
			}
			ForEach(1...5, id: \.self) { star in
				Button {
					if interactive { onRate?(star) }
				} label: {
					Image(systemName: star <= rating ? "star.fill" : "star")
						.foregroundStyle(star <= rating ? .yellow : .secondary)
						.font(.caption)
				}
				.buttonStyle(.plain)
			}
		}
	}
}

#Preview {
	@Previewable @State var rating = 3

	VStack(spacing: 20) {
		StarRatingView(rating: rating, interactive: true) { newRating in
			rating = newRating
		}
		StarRatingView(rating: 0)
		StarRatingView(rating: 5)
	}
	.padding()
}
