//
//  UDDFImportErrorTests.swift
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
import SwiftData
@testable import WaterLogged

/// Malformed and empty-input tests for the UDDF importer. Asserts the exact
/// error case rather than "some error".
@MainActor
@Suite(.tags(.importExport, .malformedInput))
struct UDDFImportErrorTests {

	// `container` must be stored: a ModelContext does not retain its container.
	// Swift Testing builds a fresh suite instance per test, so each test still
	// gets its own isolated store.
	let container: ModelContainer
	let context: ModelContext

	init() throws {
		container = try TestModelContainer.make()
		context = container.mainContext
	}

	private func expectImportError(
		_ xml: String,
		_ expected: UDDFImporter.ImportError,
		sourceLocation: SourceLocation = #_sourceLocation
	) throws {
		let error = #expect(throws: UDDFImporter.ImportError.self, sourceLocation: sourceLocation) {
			try UDDFImporter.importData(Data(xml.utf8), into: context)
		}
		#expect(error == expected, sourceLocation: sourceLocation)
	}

	@Test func emptyDocumentThrowsNoImportableData() throws {
		try expectImportError(UDDFFixtures.emptyDocument, .noImportableData)
	}

	@Test func truncatedDocumentThrowsParsingFailed() throws {
		let error = #expect(throws: UDDFImporter.ImportError.self) {
			try UDDFImporter.importData(Data(UDDFFixtures.truncated.utf8), into: context)
		}
		// The associated string varies by platform, so match only the case.
		if case .parsingFailed = error {
			// expected
		} else {
			Issue.record("Expected .parsingFailed, got \(String(describing: error))")
		}
	}

	@Test func unclosedTagThrowsParsingFailed() throws {
		let error = #expect(throws: UDDFImporter.ImportError.self) {
			try UDDFImporter.importData(Data(UDDFFixtures.unclosedTag.utf8), into: context)
		}
		if case .parsingFailed = error {
			// expected
		} else {
			Issue.record("Expected .parsingFailed, got \(String(describing: error))")
		}
	}

	@Test func malformedInputDoesNotPartiallyPersist() throws {
		_ = try? UDDFImporter.importData(Data(UDDFFixtures.truncated.utf8), into: context)
		// A parse failure must not leave stray dives behind.
		let diveCount = try context.fetchCount(FetchDescriptor<Dive>())
		#expect(diveCount == 0)
	}
}

// Friendlier failure output for the importer's error enum. Test-target only.
extension UDDFImporter.ImportError: @retroactive CustomTestStringConvertible {
	public var testDescription: String {
		switch self {
			case .parsingFailed(let detail): "parsingFailed(\(detail))"
			case .noImportableData: "noImportableData"
		}
	}
}

extension UDDFImporter.ImportError: @retroactive Equatable {
	public static func == (lhs: Self, rhs: Self) -> Bool {
		switch (lhs, rhs) {
			case (.noImportableData, .noImportableData): true
			case let (.parsingFailed(a), .parsingFailed(b)): a == b
			default: false
		}
	}
}
