//
//  FileMenuCommands.swift
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

/// Customizes the macOS File menu: replaces the default `File > New` items
/// (which would otherwise open extra app windows for each `WindowGroup`) with
/// a `New` submenu of entry sheets, an `Import` submenu, and a `Bulk Updater`
/// entry. All actions are dispatched through a shared `NewItemIntent`.
struct FileMenuCommands: Commands {
	let intent: NewItemIntent

	var body: some Commands {
		CommandGroup(replacing: .newItem) {
			Menu("New", systemImage: "plus") {
				Button("New Dive", systemImage: "water.waves.and.arrow.trianglehead.down") {
					intent.pending = .dive
				}
				.keyboardShortcut("d")
				Button("New Dive Site", systemImage: "mappin.and.ellipse") {
					intent.pending = .diveSite
				}
				.keyboardShortcut("s")
				Button("New Trip", systemImage: "airplane.path.dotted") {
					intent.pending = .trip
				}
				.keyboardShortcut("t")
				Button("New Buddy", systemImage: "person.2") {
					intent.pending = .buddy
				}
				.keyboardShortcut("b")
				Button("New Equipment", systemImage: "briefcase") {
					intent.pending = .equipment
				}
				.keyboardShortcut("e")
				Button("New Gas Mix", systemImage: "aqi.medium") {
					intent.pending = .gasMix
				}
				.keyboardShortcut("g")
			}
			Menu("Import", systemImage: "square.and.arrow.down") {
				Button("Import from UDDF", systemImage: "doc") {
					intent.showingUDDFImport = true
				}
				Button("Import from Dive Computer", systemImage: "antenna.radiowaves.left.and.right") {
					intent.showingDiveComputerImport = true
				}
			}
			Button("Bulk Updater", systemImage: "square.and.arrow.up.on.square") {
				intent.showingBulkUpdater = true
			}
			Button("Backup", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90") {
				intent.showingBackup = true
			}
			Button("Restore", systemImage: "clock.arrow.trianglehead.2.counterclockwise.rotate.90") {
				intent.showingRestore = true
			}
		}
	}
}
#endif
