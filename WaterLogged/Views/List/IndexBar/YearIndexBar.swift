//
//  YearIndexBar.swift
//  WaterLogged
//
//  Created by John Meyer on 7/28/26.
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

import SwiftUI
import SwiftData

/// A jump index that lets the user reach a trip in a long list by the year it started. Tapping a year
/// scrolls to the first trip of that year, matching the list's order (newest- or oldest-first). On tall
/// (portrait) displays it shows every distinct year; on short (landscape) displays, or whenever there
/// are more years than will comfortably fit, it collapses to a strided subset separated by dots. The
/// caller decides landscape via `condensed`, keying off the vertical size class so the choice stays
/// stable rather than flipping on a measured height as a large navigation title collapses. Presentation
/// is handled by `IndexColumn`; this type supplies the labels and the jump behavior.
struct YearIndexBar: View {

	/// A single jump target: a trip's start year paired with its identity so the list can scroll to it.
	struct Entry: Identifiable, Equatable {
		let id: PersistentIdentifier
		let year: Int
	}

	/// The trips' start years, in the same order as the list they accompany.
	let entries: [Entry]

	/// Whether to show the condensed (dotted) form for short displays instead of every year.
	let condensed: Bool

	/// Called with the first trip of the tapped year.
	let onSelect: (Entry) -> Void

	/// The bar is only worth showing beyond this many trips; the caller decides whether to include it.
	static let minimumTripCount = 20

	/// Beyond this many distinct years the column condenses even on a tall display, so the labels never
	/// crowd or clip.
	static let maximumFullCount = 26

	/// The most years the condensed form shows; the stride grows so this is never exceeded.
	private static let maximumCondensedCount = 12

	/// The distinct years, in list order, with duplicates removed. Because the entries are sorted by
	/// date, the years are monotonic (descending for newest-first, ascending for oldest-first).
	private var orderedYears: [Int] {
		var seen: Set<Int> = []
		return entries.compactMap { seen.insert($0.year).inserted ? $0.year : nil }
	}

	var body: some View {
		let years = orderedYears
		let showDots = condensed || years.count > Self.maximumFullCount
		let shown = showDots ? condensedYears(from: years) : years
		return IndexColumn(items: shown.map { year in
			IndexColumn.Item(id: year, text: year.formatted(.number.grouping(.never))) {
				if let entry = entries.first(where: { $0.year == year }) {
					onSelect(entry)
				}
			}
		}, showsDots: showDots)
	}

	/// Every `stride`-th year from `years`, always ending on the last year, where the stride is chosen so
	/// the result never exceeds `maximumCondensedCount`.
	private func condensedYears(from years: [Int]) -> [Int] {
		guard years.count > Self.maximumCondensedCount else { return years }
		let step = max(2, Int((Double(years.count) / Double(Self.maximumCondensedCount)).rounded(.up)))
		var result = stride(from: 0, to: years.count, by: step).map { years[$0] }
		if let last = years.last, result.last != last {
			result.append(last)
		}
		return result
	}
}
