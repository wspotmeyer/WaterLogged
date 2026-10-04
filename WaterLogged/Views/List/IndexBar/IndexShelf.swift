//
//  IndexShelf.swift
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
import SwiftData

/// Wraps a list in the slide-out jump-index shelf shared by the list screens: a liquid-glass
/// `IndexToggleButton` on the trailing edge that reveals an index column alongside the list. The shelf
/// owns the reveal state and the `ScrollViewReader`, handing the column a `scrollTo` closure so a tapped
/// index label scrolls the list to a row by its persistent id.
private struct IndexShelfModifier<Bar: View>: ViewModifier {

	/// Whether the list is long enough for the index to be worth offering; when false the toggle and
	/// column are hidden entirely.
	let isAvailable: Bool

	/// Builds the index column, given a closure that scrolls the list to a row's persistent id.
	@ViewBuilder let bar: (@escaping (PersistentIdentifier) -> Void) -> Bar

	@State private var isExpanded = false
	@Namespace private var namespace

	func body(content: Content) -> some View {
		ScrollViewReader { proxy in
			HStack(spacing: 0) {
				content

				if isAvailable && isExpanded {
					bar { id in
						withAnimation {
							proxy.scrollTo(id, anchor: .top)
						}
					}
					.overlay(alignment: .bottomTrailing) {
						IndexToggleButton(isExpanded: true) {
							withAnimation(.snappy) { isExpanded = false }
						}
						.matchedGeometryEffect(id: "indexToggle", in: namespace)
						.padding(.bottom, 8)
					}
					.transition(.move(edge: .trailing).combined(with: .opacity))
				}
			}
			.overlay(alignment: .trailing) {
				if isAvailable && !isExpanded {
					IndexToggleButton(isExpanded: false) {
						withAnimation(.snappy) { isExpanded = true }
					}
					.matchedGeometryEffect(id: "indexToggle", in: namespace)
				}
			}
		}
	}
}

extension View {
	/// Reveals `bar` — a jump-index column — beside this list via a slide-out shelf. See
	/// `IndexShelfModifier`. The `bar` builder receives a `scrollTo` closure to jump the list to a row.
	func indexShelf<Bar: View>(
		isAvailable: Bool,
		@ViewBuilder bar: @escaping (@escaping (PersistentIdentifier) -> Void) -> Bar
	) -> some View {
		modifier(IndexShelfModifier(isAvailable: isAvailable, bar: bar))
	}
}
