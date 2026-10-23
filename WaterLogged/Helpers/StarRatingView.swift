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

	/// The highest rating, which is also the number of stars shown.
	static let maximumRating = 5

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
			ForEach(1...Self.maximumRating, id: \.self) { star in
				// Only an editable rating's stars are buttons, so a read-only rating isn't
				// announced as a set of controls that do nothing.
				if interactive {
					Button {
						onRate?(star)
					} label: {
						StarImage(isFilled: star <= rating)
					}
					.buttonStyle(.plain)
				} else {
					StarImage(isFilled: star <= rating)
				}
			}
		}
		// VoiceOver reads the stars as one rating instead of five unlabeled symbols. An editable
		// rating is changed by swiping up or down on it rather than finding each star.
		.accessibilityElement(children: .ignore)
		.accessibilityLabel("Rating")
		.accessibilityValue(rating > 0 ? Text("\(rating) of \(Self.maximumRating) stars") : Text("No rating"))
		.modifier(AdjustableRating(rating: rating, isEnabled: interactive, onRate: onRate))
	}
}

/// One star, filled for the stars up to and including the rating.
private struct StarImage: View {
	let isFilled: Bool

	var body: some View {
		Image(systemName: isFilled ? "star.fill" : "star")
			.foregroundStyle(isFilled ? .yellow : .secondary)
			.font(.caption)
	}
}

/// Makes an editable rating adjustable with VoiceOver, one star per swipe. A read-only rating is
/// left alone, so VoiceOver doesn't offer to adjust it.
private struct AdjustableRating: ViewModifier {
	let rating: Int
	let isEnabled: Bool
	let onRate: ((Int) -> Void)?

	func body(content: Content) -> some View {
		if isEnabled {
			content
				.accessibilityAdjustableAction { direction in
					if direction == .increment {
						onRate?(min(rating + 1, StarRatingView.maximumRating))
					} else if direction == .decrement {
						onRate?(max(rating - 1, 0))
					}
				}
		} else {
			content
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
