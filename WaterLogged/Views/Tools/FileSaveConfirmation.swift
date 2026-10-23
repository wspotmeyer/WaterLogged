//
//  FileSaveConfirmation.swift
//  WaterLogged
//
//  Created by John Meyer on 10/23/26.
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

/// Builds the confirmation that `BackupToolView` and `UDDFExportToolView` show
/// (and VoiceOver announces) once `fileMover` reports that the exported file
/// reached the folder the user picked.
nonisolated enum FileSaveConfirmation {
	/// The confirmation text for a saved file.
	///
	/// - Parameters:
	///   - fileName: The file's name at its destination.
	///   - folderName: The destination folder's display name, or `nil` when it
	///     can't be read. Blank names are treated as unknown.
	static func message(fileName: String, folderName: String?) -> String {
		if let folderName, !folderName.trimmingCharacters(in: .whitespaces).isEmpty, folderName != "/" {
			return String(localized: "Saved “\(fileName)” to \(folderName).")
		}
		return String(localized: "Saved “\(fileName)”.")
	}

	/// The confirmation text for a file saved at `url`. Uses the destination
	/// folder's localized name (e.g. "iCloud Drive" rather than
	/// "com~apple~CloudDocs") when the system provides one.
	static func message(for url: URL) -> String {
		let folder = url.deletingLastPathComponent()
		let accessing = url.startAccessingSecurityScopedResource()
		defer { if accessing { url.stopAccessingSecurityScopedResource() } }
		let folderName = (try? folder.resourceValues(forKeys: [.localizedNameKey]))?.localizedName
			?? folder.lastPathComponent
		return message(fileName: url.lastPathComponent, folderName: folderName)
	}
}
