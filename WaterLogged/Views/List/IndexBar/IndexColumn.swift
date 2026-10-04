//
//  IndexColumn.swift
//  WaterLogged
//
//  Created by John Meyer on 7/28/26.
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

/// The shared presentation for a jump index, styled after the alphabet index in the Contacts app: a
/// vertical column of tappable labels with the app's index-bar chrome. When `showsDots` is set, a dot
/// is drawn between consecutive labels, standing in for the labels skipped by a condensed (landscape)
/// index. The specific bars — `DiveNumberIndexBar`, `LetterIndexBar`, `YearIndexBar` — supply the
/// labels and jump behavior; this view owns only how they look.
struct IndexColumn<ID: Hashable>: View {

	/// A single label in the column: what to show, whether it is dimmed (a jump target with no exact
	/// match, e.g. a letter no row starts with), and what to do when tapped.
	struct Item: Identifiable {
		let id: ID
		let text: String
		var dimmed: Bool = false
		let action: () -> Void
	}

	let items: [Item]
	let showsDots: Bool

	var body: some View {
		VStack(spacing: 1) {
			ForEach(items.enumerated(), id: \.element.id) { index, item in
				button(item)
				if showsDots && index < items.count - 1 {
					dot
				}
			}
		}
		.frame(minWidth: 32)
		.padding(.horizontal, 4)
		.frame(maxHeight: .infinity)
		.appGradient()
	}

	private func button(_ item: Item) -> some View {
		Button(action: item.action) {
			Text(item.text)
				.font(.caption2)
				.monospacedDigit()
				.foregroundStyle(.tint)
				.opacity(item.dimmed ? 0.35 : 1)
				.lineLimit(1)
				.fixedSize()
				.padding(.vertical, 1)
				.padding(.horizontal, 6)
				.contentShape(.rect)
		}
		.buttonStyle(.plain)
	}

	private var dot: some View {
		Text(verbatim: "•")
			.font(.caption2)
			.foregroundStyle(.tint)
			.opacity(0.5)
	}
}
