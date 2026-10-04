//
//  ImageFileHelper.swift
//  WaterLogged
//
//  Created by John Meyer on 4/25/26.
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
import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

enum ImageFileHelper {
	/// The image formats the app's file importers accept.
	static let importableTypes: [UTType] = [.jpeg, .png, .gif, .tiff]

	static func fileExtension(for data: Data) -> String {
		guard data.count >= 12 else { return "jpg" }
		let bytes = [UInt8](data.prefix(12))
		if bytes[0] == 0xFF && bytes[1] == 0xD8 { return "jpg" }
		if bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 { return "png" }
		if bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 { return "gif" }
		if (bytes[0] == 0x49 && bytes[1] == 0x49) || (bytes[0] == 0x4D && bytes[1] == 0x4D) { return "tiff" }
		if bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70 { return "heic" }
		return "jpg"
	}

	/// Loads the raw image data behind a Photos picker selection, or `nil` when
	/// there's no selection or it can't be loaded.
	static func loadData(from item: PhotosPickerItem?) async -> Data? {
		guard let item else { return nil }
		return try? await item.loadTransferable(type: Data.self)
	}

	/// Reads the file chosen in a file importer, holding its security-scoped
	/// access open for the read. `nil` if the pick failed or can't be read.
	static func loadData(from result: Result<URL, Error>) -> Data? {
		guard let url = try? result.get() else { return nil }
		guard url.startAccessingSecurityScopedResource() else { return nil }
		defer { url.stopAccessingSecurityScopedResource() }
		return try? Data(contentsOf: url)
	}

	static func defaultFilename(for data: Data) -> String {
		"Photo.\(fileExtension(for: data))"
	}

	static func shareableFile(data: Data, filename: String) -> ShareableImageFile {
		let name = filename.isEmpty ? defaultFilename(for: data) : filename
		let dir = URL.temporaryDirectory.appending(path: UUID().uuidString)
		try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
		let url = dir.appending(path: name)
		try? data.write(to: url)
		return ShareableImageFile(url: url, filename: name)
	}
}

struct ShareableImageFile: Transferable {
	let url: URL
	let filename: String

	static var transferRepresentation: some TransferRepresentation {
		FileRepresentation(exportedContentType: .image) { file in
			SentTransferredFile(file.url, allowAccessingOriginalFile: true)
		}
		.suggestedFileName(\.filename)
	}
}
