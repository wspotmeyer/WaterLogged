//
//  OpenBuddyIntent.swift
//  WaterLogged
//
//  Created by John Meyer on 6/27/26.
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
//

import AppIntents

/// Opens a buddy's detail view. Spotlight runs this intent when a person taps
/// an indexed `BuddyAppEntity` in search results, bringing the app forward and
/// routing to the buddy via `NavigationRouter`. See `OpenDiveSiteIntent` for the
/// note on isolation.
struct OpenBuddyIntent: OpenIntent {

	static let title: LocalizedStringResource = "Open Buddy"

	@Parameter(title: "Buddy")
	var target: BuddyAppEntity

	func perform() async throws -> some IntentResult {
		let id = target.id
		await MainActor.run {
			NavigationRouter.shared.pending = .buddy(id: id)
		}
		return .result()
	}
}
