//
//  ZipReader.swift
//  WaterLogged
//
//  Created by John Meyer on 4/27/26.
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
import Compression

/// Extracts standard ZIP archives to a destination directory.
///
/// Supports compression methods 0 (stored) and 8 (deflate). Uses Apple's
/// Compression framework for decompression — no third-party dependencies.
struct ZipReader {

	enum ZipError: LocalizedError {
		case invalidArchive
		case unsupportedCompression(Int)
		case decompressionFailed(String)

		var errorDescription: String? {
			switch self {
				case .invalidArchive: "The file is not a valid zip archive."
				case .unsupportedCompression(let method): "Unsupported compression method \(method) in archive."
				case .decompressionFailed(let name): "Failed to decompress entry: \(name)"
			}
		}
	}

	/// Extracts all files from a ZIP archive to the given directory.
	static func extractArchive(at zipURL: URL, to destinationDir: URL) throws {
		let data = try Data(contentsOf: zipURL)
		let fm = FileManager.default
		try fm.createDirectory(at: destinationDir, withIntermediateDirectories: true)

		let eocdOffset = try findEOCD(in: data)
		let entryCount = Int(readUInt16(data, at: eocdOffset + 10))
		var cdOffset = Int(readUInt32(data, at: eocdOffset + 16))

		for _ in 0..<entryCount {
			guard cdOffset + 46 <= data.count else { break }
			guard readUInt32(data, at: cdOffset) == 0x02014b50 else {
				throw ZipError.invalidArchive
			}

			let method = Int(readUInt16(data, at: cdOffset + 10))
			let compressedSize = Int(readUInt32(data, at: cdOffset + 20))
			let uncompressedSize = Int(readUInt32(data, at: cdOffset + 24))
			let nameLength = Int(readUInt16(data, at: cdOffset + 28))
			let extraLength = Int(readUInt16(data, at: cdOffset + 30))
			let commentLength = Int(readUInt16(data, at: cdOffset + 32))
			let localHeaderOffset = Int(readUInt32(data, at: cdOffset + 42))

			let nameEnd = cdOffset + 46 + nameLength
			guard nameEnd <= data.count else { break }
			let filename = String(data: data[(cdOffset + 46)..<nameEnd], encoding: .utf8) ?? ""

			cdOffset = nameEnd + extraLength + commentLength

			if filename.hasPrefix("__MACOSX") || filename.isEmpty { continue }

			if filename.hasSuffix("/") {
				try fm.createDirectory(
					at: destinationDir.appending(path: filename),
					withIntermediateDirectories: true
				)
				continue
			}

			guard localHeaderOffset + 30 <= data.count,
				  readUInt32(data, at: localHeaderOffset) == 0x04034b50 else { continue }

			let localNameLength = Int(readUInt16(data, at: localHeaderOffset + 26))
			let localExtraLength = Int(readUInt16(data, at: localHeaderOffset + 28))
			let dataStart = localHeaderOffset + 30 + localNameLength + localExtraLength

			guard dataStart + compressedSize <= data.count else { continue }

			let fileData: Data
			switch method {
				case 0:
					fileData = Data(data[dataStart..<(dataStart + compressedSize)])
				case 8:
					fileData = try decompressDeflate(
						data[dataStart..<(dataStart + compressedSize)],
						uncompressedSize: uncompressedSize,
						filename: filename
					)
				default:
					throw ZipError.unsupportedCompression(method)
			}

			let fileURL = destinationDir.appending(path: filename)
			try fm.createDirectory(
				at: fileURL.deletingLastPathComponent(),
				withIntermediateDirectories: true
			)
			try fileData.write(to: fileURL)
		}
	}

	// MARK: - Private

	private static func findEOCD(in data: Data) throws -> Int {
		let minSize = 22
		guard data.count >= minSize else { throw ZipError.invalidArchive }

		let searchStart = max(0, data.count - 65557)
		for offset in stride(from: data.count - minSize, through: searchStart, by: -1)
				where readUInt32(data, at: offset) == 0x06054b50 {
			return offset
		}
		throw ZipError.invalidArchive
	}

	private static func decompressDeflate(
		_ compressed: Data,
		uncompressedSize: Int,
		filename: String
	) throws -> Data {
		guard uncompressedSize > 0 else { return Data() }

		let src = Array(compressed)
		var dest = [UInt8](repeating: 0, count: uncompressedSize)

		let decoded = compression_decode_buffer(
			&dest, uncompressedSize,
			src, src.count,
			nil,
			COMPRESSION_ZLIB
		)

		guard decoded == uncompressedSize else {
			throw ZipError.decompressionFailed(filename)
		}

		return Data(dest)
	}

	private static func readUInt16(_ data: Data, at offset: Int) -> UInt16 {
		UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
	}

	private static func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
		UInt32(data[offset]) | UInt32(data[offset + 1]) << 8
		| UInt32(data[offset + 2]) << 16 | UInt32(data[offset + 3]) << 24
	}
}
