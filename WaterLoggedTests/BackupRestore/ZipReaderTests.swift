//
//  ZipReaderTests.swift
//  WaterLoggedTests
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

import Testing
import Foundation
@testable import WaterLogged

@Suite(.tags(.backup))
struct ZipReaderTests {

	/// Writes archive bytes to a temp file and extracts them, returning the
	/// extraction directory for inspection.
	private func extract(_ archive: Data, _ body: (URL) throws -> Void) throws {
		try withTemporaryDirectory { dir in
			let zipURL = dir.appending(path: "archive.zip")
			try archive.write(to: zipURL)
			let destination = dir.appending(path: "out")
			try ZipReader.extractArchive(at: zipURL, to: destination)
			try body(destination)
		}
	}

	// MARK: - Valid archives

	@Test func storedEntryExtractsContent() throws {
		let payload = Data("hello uddf".utf8)
		let archive = RawZip.make([.init(name: "logbook.uddf", data: payload)])
		try extract(archive) { out in
			let extracted = try Data(contentsOf: out.appending(path: "logbook.uddf"))
			#expect(extracted == payload)
		}
	}

	@Test func nestedPathCreatesSubdirectories() throws {
		let payload = Data("image".utf8)
		let archive = RawZip.make([.init(name: "media/photo_1.jpg", data: payload)])
		try extract(archive) { out in
			let extracted = try Data(contentsOf: out.appending(path: "media/photo_1.jpg"))
			#expect(extracted == payload)
		}
	}

	@Test func multipleEntriesAllExtract() throws {
		let archive = RawZip.make([
			.init(name: "logbook.uddf", data: Data("a".utf8)),
			.init(name: "extras.xml", data: Data("b".utf8))
		])
		try extract(archive) { out in
			let logbook = try Data(contentsOf: out.appending(path: "logbook.uddf"))
			let extras = try Data(contentsOf: out.appending(path: "extras.xml"))
			#expect(logbook == Data("a".utf8))
			#expect(extras == Data("b".utf8))
		}
	}

	// MARK: - Corrupt archives

	@Test(.tags(.malformedInput)) func randomBytesThrowInvalidArchive() throws {
		let garbage = Data((0..<128).map { _ in UInt8.random(in: 0...255) })
		try withTemporaryDirectory { dir in
			let zipURL = dir.appending(path: "bad.zip")
			try garbage.write(to: zipURL)
			let error = #expect(throws: ZipReader.ZipError.self) {
				try ZipReader.extractArchive(at: zipURL, to: dir.appending(path: "out"))
			}
			#expect(isInvalidArchive(error))
		}
	}

	@Test(.tags(.malformedInput)) func emptyFileThrowsInvalidArchive() throws {
		try withTemporaryDirectory { dir in
			let zipURL = dir.appending(path: "empty.zip")
			try Data().write(to: zipURL)
			let error = #expect(throws: ZipReader.ZipError.self) {
				try ZipReader.extractArchive(at: zipURL, to: dir.appending(path: "out"))
			}
			#expect(isInvalidArchive(error))
		}
	}

	@Test(.tags(.malformedInput)) func unsupportedCompressionMethodThrows() throws {
		// Method 99 is neither stored (0) nor deflate (8).
		let archive = RawZip.make([.init(name: "logbook.uddf", data: Data("x".utf8), method: 99)])
		try withTemporaryDirectory { dir in
			let zipURL = dir.appending(path: "archive.zip")
			try archive.write(to: zipURL)
			let error = #expect(throws: ZipReader.ZipError.self) {
				try ZipReader.extractArchive(at: zipURL, to: dir.appending(path: "out"))
			}
			if case .unsupportedCompression(let method) = error {
				#expect(method == 99)
			} else {
				Issue.record("Expected .unsupportedCompression, got \(String(describing: error))")
			}
		}
	}

	@Test(.tags(.malformedInput)) func corruptDeflatePayloadThrowsDecompressionFailed() throws {
		// Method 8 (deflate) but the stored bytes are not valid zlib data.
		let archive = RawZip.make([
			.init(name: "logbook.uddf",
				  data: Data(repeating: 0xAB, count: 64),   // claimed uncompressed size
				  method: 8,
				  storedBytes: Data([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]))
		])
		try withTemporaryDirectory { dir in
			let zipURL = dir.appending(path: "archive.zip")
			try archive.write(to: zipURL)
			let error = #expect(throws: ZipReader.ZipError.self) {
				try ZipReader.extractArchive(at: zipURL, to: dir.appending(path: "out"))
			}
			if case .decompressionFailed = error {
				// expected
			} else {
				Issue.record("Expected .decompressionFailed, got \(String(describing: error))")
			}
		}
	}

	private func isInvalidArchive(_ error: ZipReader.ZipError?) -> Bool {
		if case .invalidArchive = error { return true }
		return false
	}
}
