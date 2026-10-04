//
//  DiveTagFilterTests.swift
//  WaterLoggedTests
//
//  Created by John Meyer on 8/16/26.
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
import SwiftData
@testable import WaterLogged

/// Unit tests for the dive list's tag filter. `vocabulary` and `matches` take plain
/// `[String]` values, so most of these need no SwiftData stack; only the
/// `filtered(_:selecting:)` ordering check builds a container.
@Suite(.tags(.tagFilter))
struct DiveTagFilterTests {

	// MARK: - Matching

	@Test("An empty selection matches every dive")
	func emptySelectionMatchesEverything() {
		#expect(DiveTagFilter.matches(tags: ["reef"], selecting: []))
		#expect(DiveTagFilter.matches(tags: [], selecting: []))
	}

	@Test("A single selected tag matches only dives carrying it")
	func singleTag() {
		#expect(DiveTagFilter.matches(tags: ["reef", "coral"], selecting: ["reef"]))
		#expect(!DiveTagFilter.matches(tags: ["wreck"], selecting: ["reef"]))
		#expect(!DiveTagFilter.matches(tags: [], selecting: ["reef"]))
	}

	@Test("Every selected tag must be present, not just one")
	func multipleTagsAreAnded() {
		let tags = ["drift", "shark", "pelagic"]
		#expect(DiveTagFilter.matches(tags: tags, selecting: ["drift", "shark"]))
		#expect(DiveTagFilter.matches(tags: tags, selecting: ["drift", "shark", "pelagic"]))
		#expect(!DiveTagFilter.matches(tags: tags, selecting: ["drift", "wreck"]))
	}

	@Test("Extra tags the selection doesn't mention don't disqualify a dive")
	func supersetMatches() {
		#expect(DiveTagFilter.matches(tags: ["a", "b", "c", "d"], selecting: ["a", "c"]))
	}

	@Test("Matching folds case, so a tag typed two ways still lines up", .tags(.edgeCase))
	func matchingIsCaseInsensitive() {
		#expect(DiveTagFilter.matches(tags: ["Reef", "Coral"], selecting: ["reef"]))
		#expect(DiveTagFilter.matches(tags: ["reef"], selecting: ["REEF"]))
		#expect(DiveTagFilter.matches(tags: ["Drift", "shark"], selecting: ["drift", "SHARK"]))
	}

	@Test("Surrounding whitespace doesn't stop a tag from matching", .tags(.edgeCase))
	func matchingTrimsWhitespace() {
		#expect(DiveTagFilter.matches(tags: [" reef "], selecting: ["reef"]))
		#expect(DiveTagFilter.matches(tags: ["reef"], selecting: [" reef"]))
	}

	// MARK: - Vocabulary

	@Test("The vocabulary is the distinct tags in localized alphabetical order")
	func vocabularyIsSortedAndDistinct() {
		let vocabulary = DiveTagFilter.vocabulary(from: [
			["wreck", "history"],
			["reef", "coral"],
			["wreck"]
		])
		#expect(vocabulary == ["coral", "history", "reef", "wreck"])
	}

	@Test("Case variants of one tag collapse to a single entry", .tags(.edgeCase))
	func vocabularyFoldsCaseVariants() {
		let vocabulary = DiveTagFilter.vocabulary(from: [["Reef"], ["reef"], ["REEF", "wreck"]])
		#expect(vocabulary.count == 2)
		#expect(vocabulary.last == "wreck")
		// Whichever spelling survives must still match dives that used the others.
		let survivor = vocabulary[0]
		#expect(DiveTagFilter.matches(tags: ["reef"], selecting: [survivor]))
		#expect(DiveTagFilter.matches(tags: ["REEF"], selecting: [survivor]))
	}

	@Test("Empty and whitespace-only tags are dropped", .tags(.edgeCase))
	func vocabularyDropsEmptyTags() {
		#expect(DiveTagFilter.vocabulary(from: [["", "  ", "reef"], []]) == ["reef"])
		#expect(DiveTagFilter.vocabulary(from: []).isEmpty)
		#expect(DiveTagFilter.vocabulary(from: [[]]).isEmpty)
	}

	@Test("Whitespace around a tag doesn't create a second entry", .tags(.edgeCase))
	func vocabularyTrimsWhitespace() {
		#expect(DiveTagFilter.vocabulary(from: [[" reef ", "reef"]]) == ["reef"])
	}

	// MARK: - Filtering dives

	@MainActor
	@Test("Filtering keeps the dives carrying every tag, in the order given")
	func filteringPreservesOrder() throws {
		// Hold the container: a ModelContext does not retain the container that made it.
		let container = try TestModelContainer.make()
		let context = container.mainContext

		let first = Dive(diveNumber: 1, tags: ["drift", "shark"])
		let second = Dive(diveNumber: 2, tags: ["reef"])
		let third = Dive(diveNumber: 3, tags: ["shark", "drift", "pelagic"])
		for dive in [first, second, third] {
			context.insert(dive)
		}

		let ordered = [third, second, first]
		let result = DiveTagFilter.filtered(ordered, selecting: ["drift", "shark"])
		#expect(result.map(\.diveNumber) == [3, 1])

		#expect(DiveTagFilter.filtered(ordered, selecting: []).count == 3)
		#expect(DiveTagFilter.filtered(ordered, selecting: ["wreck"]).isEmpty)
	}
}
