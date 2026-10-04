//
//  NewItemIntent.swift
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

import Foundation

/// Shared coordinator that bridges App-level menu commands to the sheets and
/// importers presented inside the main window. Each flag corresponds to a
/// specific File-menu action; the binding clears itself on dismissal.
@MainActor
@Observable
final class NewItemIntent {
	/// Set by `File > New > …` to present the matching entry sheet.
	var pending: NewItemKind?

	/// Set by `File > Import > Import from UDDF` to present a UDDF file picker.
	var showingUDDFImport: Bool = false

	/// Set by `File > Import > Import from Dive Computer` to present the
	/// dive-computer scanning/transfer sheet.
	var showingDiveComputerImport: Bool = false

	/// Set by `File > Bulk Updater` to present the bulk-update tool.
	var showingBulkUpdater: Bool = false

	/// Set by `File > Backup` to present the backup tool.
	var showingBackup: Bool = false

	/// Set by `File > Restore` to present the restore tool.
	var showingRestore: Bool = false
}
