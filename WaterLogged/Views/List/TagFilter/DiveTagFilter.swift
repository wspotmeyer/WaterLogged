//
//  DiveTagFilter.swift
//  WaterLogged
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

import Foundation

/// Builds the tag vocabulary offered by the dive list's tag filter, and decides which dives the
/// selected tags keep.
///
/// A dive matches when it carries *every* selected tag; extra tags it doesn't share with the selection
/// are fine. An empty selection matches everything, so the filter is off by default.
///
/// This deliberately works on `[String]` rather than `Dive` so the rules can be exercised without a
/// `ModelContainer`, and it runs in Swift rather than inside the `@Query` predicate. A SwiftData
/// `#Predicate` *can* test `tags`: `$0.tags.contains(tag)` translates fine, as does an explicit
/// `contains(a) && contains(b)`. What it cannot do is fold a **variable** number of those terms
/// together — the natural spelling, `selected.allSatisfy { dive.tags.contains($0) }`, aborts the
/// process at fetch time rather than throwing. Since the number of selected tags is only known at
/// runtime, the conjunction lives here instead. That costs nothing: `@Query` already materializes its
/// whole result array for the list, so this filters objects that are loaded either way.
enum DiveTagFilter {

	/// The distinct tags used across `tagLists`, in localized alphabetical order.
	///
	/// Tags are free text typed into the dive form, so `"Reef"` and `"reef"` routinely coexist. Those
	/// collapse into one entry — otherwise the filter strip offers the same tag twice, and picking one
	/// spelling silently hides dives that used the other. The surviving spelling is the first in sorted
	/// order, which keeps the choice stable as dives come and go.
	nonisolated static func vocabulary(from tagLists: [[String]]) -> [String] {
		let tags = tagLists
			.flatMap { $0 }
			.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
			.filter { !$0.isEmpty }
			.sorted { $0.localizedStandardCompare($1) == .orderedAscending }

		var seen: Set<String> = []
		return tags.filter { seen.insert(foldedTag($0)).inserted }
	}

	/// Whether a dive carrying `tags` should survive the given selection.
	nonisolated static func matches(tags: [String], selecting selected: Set<String>) -> Bool {
		guard !selected.isEmpty else { return true }
		let folded = Set(tags.map(foldedTag))
		return Set(selected.map(foldedTag)).isSubset(of: folded)
	}

	/// The dives carrying every selected tag, in the order they were given.
	///
	/// The only member that touches `Dive`, so the only one that stays on the main actor.
	static func filtered(_ dives: [Dive], selecting selected: Set<String>) -> [Dive] {
		guard !selected.isEmpty else { return dives }
		return dives.filter { matches(tags: $0.tags, selecting: selected) }
	}

	/// The form two spellings of the same tag are compared in.
	///
	/// Case folding only: tags are compared for equality here — never searched as substrings — so
	/// `localizedStandardContains()` doesn't apply.
	nonisolated private static func foldedTag(_ tag: String) -> String {
		tag.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
	}
}
