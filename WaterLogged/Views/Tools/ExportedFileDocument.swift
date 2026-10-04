//
//  ExportedFileDocument.swift
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

#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers

/// Hands an already-written export file (a backup `.zip` or a `.uddf`) to
/// `fileExporter` on macOS. The caller passes the matching `contentType` to
/// `fileExporter`; this type only copies the file's bytes.
///
/// Must stay `nonisolated`: `fileExporter` calls `fileWrapper(configuration:)`
/// off the main actor.
nonisolated struct ExportedFileDocument: FileDocument {
	static let readableContentTypes: [UTType] = [.zip, .uddf]
	static let writableContentTypes: [UTType] = [.zip, .uddf]

	let sourceURL: URL

	init(url: URL) {
		self.sourceURL = url
	}

	init(configuration: ReadConfiguration) throws {
		throw CocoaError(.featureUnsupported)
	}

	func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
		let data = try Data(contentsOf: sourceURL)
		let wrapper = FileWrapper(regularFileWithContents: data)
		wrapper.preferredFilename = sourceURL.lastPathComponent
		return wrapper
	}
}
#endif
