//
//  NavigationRouter.swift
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

import Foundation

/// Shared navigation state that lets out-of-app entry points — currently the
/// `OpenIntent`s a person triggers by tapping a WaterLogged result in Spotlight
/// — deep-link into the matching detail view.
///
/// An `OpenIntent` runs in the app process but outside the SwiftUI environment,
/// so it can't reach view state directly. It instead sets `pending` on this
/// shared instance; the view tree observes that and routes to the target:
/// `AdaptiveRootView` selects the owning tab, and the destination list view
/// resolves the entity's `externalId` to its model, selects it, and clears
/// `pending`.
///
/// A singleton (rather than an injected environment object) keeps the intent
/// side simple — `NavigationRouter.shared` is reachable from a `perform()` with
/// no plumbing — while views still observe it through `@Observable`.
@MainActor
@Observable
final class NavigationRouter {
	static let shared = NavigationRouter()
	private init() {}

	/// A request to surface a specific record. Carries the model's `externalId`
	/// (the stable id the entities expose), which the destination list view
	/// resolves against SwiftData.
	enum Destination: Equatable {
		case dive(id: String)
		case diveSite(id: String)
		case buddy(id: String)
		case trip(id: String)
	}

	/// The destination awaiting navigation, or `nil` when there's nothing
	/// pending. The destination list view clears this once it has selected the
	/// matching record.
	var pending: Destination?
}
