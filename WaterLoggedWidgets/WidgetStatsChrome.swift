//
//  WidgetStatsChrome.swift
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

import WidgetKit
import SwiftUI

/// Shared presentation applied to every "Dive Stats" widget content view: the dark
/// navy gradient background, a pinned dark color scheme so semantic styles stay
/// legible against it, and the deep link that opens the app on the Statistics view.
private struct WidgetStatsChrome: ViewModifier {
	func body(content: Content) -> some View {
		content
		// The dark navy gradient is used in both system appearances, so
		// pin the color scheme to dark to keep semantic styles legible.
			.environment(\.colorScheme, .dark)
			.containerBackground(for: .widget) {
				WidgetGradientBackground()
			}
			.widgetURL(URL(string: WidgetShared.deepLinkString))
	}
}

extension View {
	/// Applies the shared gradient background, dark color scheme, and Statistics
	/// deep link used by all of the WaterLogged stats widgets.
	func widgetStatsChrome() -> some View {
		modifier(WidgetStatsChrome())
	}
}
