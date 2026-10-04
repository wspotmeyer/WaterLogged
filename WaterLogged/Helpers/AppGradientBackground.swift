//
//  AppGradientBackground.swift
//  WaterLogged
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

/// The app-wide background gradient. The two stops are defined as adaptive
/// color sets in the asset catalog, so the gradient automatically switches
/// between its light and dark variants without any `colorScheme` branching.
struct AppGradientBackground: View {
	var body: some View {
		LinearGradient(
			colors: [.backgroundGradientTop, .backgroundGradientBottom],
			startPoint: .top,
			endPoint: .bottom
		)
		.ignoresSafeArea()
	}
}

extension View {
	/// Places the shared `AppGradientBackground` directly behind this view's
	/// frame. Use on plain (non-scrolling) screens.
	func appGradient() -> some View {
		background(AppGradientBackground())
	}

	/// For `List`, `Form`, and `ScrollView` content. Hides the system scroll
	/// background and paints the shared gradient inside the container's own
	/// frame, so it shows through even when the container is nested inside a
	/// `NavigationSplitView` or `TabView` whose columns are otherwise opaque.
	///
	/// Note: this does NOT tint `List`/`Form` rows — `.listRowBackground` only
	/// takes effect when applied *inside* the container (on a `Section`,
	/// `ForEach`, or row), not on the container from the outside. To give rows
	/// the shared translucent tile color, apply `.tileListRowBackground()`
	/// inside the `List`/`Form` as well.
	func appGradientScrollBackground() -> some View {
		scrollContentBackground(.hidden)
			.background(AppGradientBackground())
	}
}

#Preview {
	Text("WaterLogged")
		.font(.largeTitle)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.appGradient()
}
