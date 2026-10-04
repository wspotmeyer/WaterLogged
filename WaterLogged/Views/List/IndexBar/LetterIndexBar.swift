//
//  LetterIndexBar.swift
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

/// A jump index that lets the user reach a row in a long, alphabetically sorted list. Tapping a letter
/// scrolls to the first entry whose section letter is at or after it (matching the list's ascending
/// order). On tall (portrait) displays it shows the whole alphabet A–Z; on short (landscape) displays,
/// where 26 rows will not fit, it collapses to a condensed set of letters separated by dots. The caller
/// decides which form via `condensed`, keying off the vertical size class so the choice stays stable
/// rather than flipping on a measured height as a large navigation title collapses. Presentation is
/// handled by `IndexColumn`; this type supplies the labels and the jump behavior.
struct LetterIndexBar: View {

	/// A single jump target: a row's section letter paired with its identity so the list can scroll to it.
	struct Entry: Identifiable, Equatable {
		let id: PersistentIdentifier
		let letter: Character
	}

	/// The rows' section letters, in the same ascending order as the list they accompany.
	let entries: [Entry]

	/// Whether to show the condensed (dotted) form for short displays instead of the full alphabet.
	let condensed: Bool

	/// Called with the row nearest to the tapped letter.
	let onSelect: (Entry) -> Void

	/// The bar is only worth showing beyond this many rows; the caller decides whether to include it.
	static let minimumRowCount = 20

	/// The full alphabet shown on tall displays.
	private static let alphabet: [Character] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")

	/// How many letters to skip between shown letters in the condensed form. A stride of three keeps
	/// the row count low enough to fit a landscape phone while still giving frequent jump targets.
	private static let condensedStride = 3

	/// The letters shown in the condensed form: every `condensedStride`-th letter, always ending on Z.
	private static let condensedLetters: [Character] = {
		var result = stride(from: 0, to: alphabet.count, by: condensedStride).map { alphabet[$0] }
		if let last = alphabet.last, result.last != last {
			result.append(last)
		}
		return result
	}()

	var body: some View {
		let letters = condensed ? Self.condensedLetters : Self.alphabet
		let present = Set(entries.map(\.letter))
		return IndexColumn(items: letters.map { letter in
			IndexColumn.Item(id: letter, text: String(letter), dimmed: !present.contains(letter)) {
				if let entry = nearestEntry(to: letter) {
					onSelect(entry)
				}
			}
		}, showsDots: condensed)
	}

	/// The first row whose section letter is at or after `letter`; if none is, the last row. Because the
	/// entries share the list's ascending order, their letters are non-decreasing and a linear scan works.
	private func nearestEntry(to letter: Character) -> Entry? {
		entries.first { $0.letter >= letter } ?? entries.last
	}
}
