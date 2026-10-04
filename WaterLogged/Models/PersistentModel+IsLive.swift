//
//  PersistentModel+IsLive.swift
//  WaterLogged
//
//  Created by John Meyer on 10/4/26.
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

import SwiftData

extension PersistentModel {
	/// Whether the model can still be read safely.
	///
	/// A model stops being live when it is deleted (`isDeleted` until the next
	/// save) or detached from its context — which is what happens to every old
	/// record when a restore replaces the logbook, and to a record that iCloud
	/// sync deletes. SwiftData traps when a view reads an attribute that has to
	/// be fetched from the store for such a model, so a view that is handed a
	/// model directly (a list row, a detail screen) checks this first and draws
	/// nothing for a dead one.
	var isLive: Bool {
		!isDeleted && modelContext != nil
	}
}
