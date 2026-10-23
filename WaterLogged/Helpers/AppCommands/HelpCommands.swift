//
//  HelpCommands.swift
//  WaterLogged
//
//  Created by John Meyer on 5/17/26.
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

#if os(macOS)
import SwiftUI

/// Replaces the standard Help menu items with links to the WaterLogged website. The app
/// ships no help book, so the stock `Help > WaterLogged Help` item would only ever fail
/// in the system Help Viewer.
struct HelpCommands: Commands {
	@Environment(\.openURL) private var openURL

	var body: some Commands {
		CommandGroup(replacing: .help) {
			if let support = WaterLoggedWebsite.support {
				Button("WaterLogged Support") {
					openURL(support)
				}
			}
			if let privacyPolicy = WaterLoggedWebsite.privacyPolicy {
				Button("Privacy Policy") {
					openURL(privacyPolicy)
				}
			}
		}
	}
}
#endif
