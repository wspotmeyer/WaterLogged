//
//  RootTab.swift
//  WaterLogged
//
//  Created by John Meyer on 7/2/26.
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

import Foundation

/// The app's top-level destinations. Each case identifies one `Tab` in
/// `AdaptiveRootView`'s root `TabView`; raw values allow the selection to be
/// persisted.
enum RootTab: String, Hashable {
	case home
	case dives
	case diveSites
	case trips
	case equipment
	case gasMixes
	case buddies
	case owner
	case tools
	case stats
	case settings
	case about
	case browse
}

extension NavigationRouter.Destination {
	/// The root tab that hosts this destination's list view.
	var rootTab: RootTab {
		switch self {
			case .dive: .dives
			case .diveSite: .diveSites
			case .trip: .trips
			case .buddy: .buddies
		}
	}
}
