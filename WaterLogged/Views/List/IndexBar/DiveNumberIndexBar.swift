//
//  DiveNumberIndexBar.swift
//  WaterLogged
//
//  Created by John Meyer on 7/27/26.
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

/// A jump index that lets the user reach a dive in a long list. Instead of letters it shows round dive
/// numbers (multiples of ten) spanning the range of the list. The increment is chosen so the labels
/// never exceed a fixed count. Presentation is handled by `IndexColumn`; this type supplies the labels
/// and the nearest-dive jump behavior.
struct DiveNumberIndexBar: View {

	/// A single jump target: a dive's number paired with its identity so the list can scroll to it.
	struct Entry: Identifiable, Equatable {
		let id: PersistentIdentifier
		let number: Int
	}

	/// The full set of dives, in the same order as the list they accompany.
	let entries: [Entry]

	/// Called with the dive nearest to the tapped round number.
	let onSelect: (Entry) -> Void

	/// The bar is only worth showing beyond this many dives; the caller decides whether to include it.
	static let minimumDiveCount = 100

	/// The most labels the column will ever show. A fixed cap (rather than a measured height) keeps the
	/// chosen increment perfectly stable — the collapsing navigation title used to shift a height-based
	/// count mid-scroll. The increment grows as needed so this many labels are never exceeded.
	static let maximumLabelCount = 20

	/// "Nice" increments, all multiples of ten, tried smallest-first until the label count fits the cap.
	private static let niceIncrements: [Int] = {
		var result: [Int] = []
		var magnitude = 10
		for _ in 0..<7 {
			for base in [1, 2, 5] {
				result.append(base * magnitude)
			}
			magnitude *= 10
		}
		return result
	}()

	var body: some View {
		IndexColumn(items: orderedLabels.map { number in
			IndexColumn.Item(id: number, text: number.formatted(.number.grouping(.never))) {
				if let entry = nearestEntry(to: number) {
					onSelect(entry)
				}
			}
		}, showsDots: false)
	}

	/// The round-number labels, ordered to match the list's sort direction (top mirrors the first row).
	private var orderedLabels: [Int] {
		let numbers = entries.map(\.number)
		guard let minNumber = numbers.min(), let maxNumber = numbers.max() else { return [] }
		let labels = Self.indexNumbers(from: minNumber, to: maxNumber, maxCount: Self.maximumLabelCount)
		let listAscends = (entries.first?.number ?? 0) <= (entries.last?.number ?? 0)
		return listAscends ? labels : labels.reversed()
	}

	/// The dive whose number is closest to the tapped round number.
	private func nearestEntry(to number: Int) -> Entry? {
		entries.min { abs($0.number - number) < abs($1.number - number) }
	}

	/// Ascending multiples of a "nice" increment covering `[minNumber, maxNumber]`. The smallest
	/// increment whose label count fits `maxCount` is chosen, so the column stays uncrowded.
	static func indexNumbers(from minNumber: Int, to maxNumber: Int, maxCount: Int) -> [Int] {
		guard maxNumber > minNumber, maxCount >= 1 else { return [] }
		for increment in niceIncrements {
			let first = ((minNumber + increment - 1) / increment) * increment   // first multiple >= min
			let last = (maxNumber / increment) * increment                      // last multiple <= max
			guard first <= last else { continue }
			let count = (last - first) / increment + 1
			if count <= maxCount {
				return Array(stride(from: first, through: last, by: increment))
			}
		}
		return []
	}
}
