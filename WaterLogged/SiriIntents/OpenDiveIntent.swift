//
//  OpenDiveIntent.swift
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

/// Opens a dive's detail view. Spotlight runs this intent when a person taps an
/// indexed `DiveAppEntity` in search results, which brings the app forward and
/// routes to the dive via `NavigationRouter`.
///
/// `perform()` is nonisolated (the `AppIntent` requirement), so it hops to the
/// main actor to set the `@MainActor` router — the same pattern the other open
/// intents use.
struct OpenDiveIntent: OpenIntent {

	static let title: LocalizedStringResource = "Open Dive"

	@Parameter(title: "Dive")
	var target: DiveAppEntity

	func perform() async throws -> some IntentResult {
		let id = target.id
		await MainActor.run {
			NavigationRouter.shared.pending = .dive(id: id)
		}
		return .result()
	}
}
