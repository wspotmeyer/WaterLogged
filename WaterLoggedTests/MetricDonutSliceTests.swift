//
//  MetricDonutSliceTests.swift
//  WaterLogged
//
//  Created by John Meyer on 9/26/26.
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

@MainActor
struct MetricDonutSliceTests {

	private func makeDives(_ count: Int, seconds: Int = 600) -> [Dive] {
		(0..<count).map { _ in Dive(durationSeconds: seconds) }
	}

	@Test func totalsEveryMetric() {
		let trip = Trip(name: "Cozumel", startDate: .distantPast, endDate: .distantPast)
		let dives = makeDives(3, seconds: 1_800)
		dives[0].trip = trip
		dives[1].trip = trip

		let slice = MetricDonutSlice(id: "salt", label: "Salt", dives: dives, paletteSlot: 0)

		#expect(slice.value.diveCount == 3)
		#expect(slice.value.bottomTimeSeconds == 5_400)
		// Two dives on the same trip, one on none.
		#expect(slice.value.tripCount == 1)
	}

	@Test func rankedAssignsSlotsByDiveCount() {
		let slices = MetricDonutSlice.ranked([
			"EAN32": makeDives(2),
			"Air": makeDives(5),
			"EAN36": makeDives(2)
		])

		// Most dives first; equal counts fall back to name order.
		#expect(slices.map(\.id) == ["Air", "EAN32", "EAN36"])
		#expect(slices.map(\.paletteSlot) == [0, 1, 2])
	}

	@Test func rankedFillsEverySlotWithoutOther() {
		let groups = Dictionary(uniqueKeysWithValues: (0..<ChartCategoryPalette.slotCount).map { ("Mix \($0)", makeDives(1)) })
		let slices = MetricDonutSlice.ranked(groups)

		#expect(slices.count == ChartCategoryPalette.slotCount)
		#expect(!slices.contains { $0.id == MetricDonutSlice.otherID })
	}

	@Test func rankedFoldsTheSmallestGroupsIntoOther() throws {
		let shared = makeDives(1, seconds: 900)
		let slices = MetricDonutSlice.ranked([
			"Air": makeDives(9),
			"EAN32": makeDives(7),
			"EAN36": makeDives(5),
			"EAN40": makeDives(3),
			// These two share a dive, which "Other" must count only once.
			"EAN50": shared + makeDives(1, seconds: 600),
			"Oxygen": shared
		])

		#expect(slices.count == ChartCategoryPalette.slotCount + 1)
		#expect(slices.map(\.paletteSlot) == [0, 1, 2, 3, nil])

		let other = try #require(slices.last)
		#expect(other.id == MetricDonutSlice.otherID)
		#expect(other.value.diveCount == 2)
		#expect(other.value.bottomTimeSeconds == 1_500)
	}

	@Test func rankedHandlesNoGroups() {
		#expect(MetricDonutSlice.ranked([:]).isEmpty)
	}

	@Test func valueLabelsPerMetric() {
		// 3 × 4,500s = 13,500s = 3h 45m.
		let slice = MetricDonutSlice(id: "air", label: "Air", dives: makeDives(3, seconds: 4_500), paletteSlot: 0)

		#expect(slice.value(for: .dives) == 3)
		#expect(slice.value(for: .bottomTime) == 13_500)
		#expect(slice.valueLabel(for: .dives) == "3")
		#expect(slice.valueLabel(for: .bottomTime) == "3h 45m")
	}

	@Test func shareOfTheRing() {
		let air = MetricDonutSlice(id: "air", label: "Air", dives: makeDives(3, seconds: 600), paletteSlot: 0)
		let nitrox = MetricDonutSlice(id: "ean32", label: "EAN32", dives: makeDives(1, seconds: 1_800), paletteSlot: 1)
		let ring = [air, nitrox]

		#expect(air.share(of: ring, for: .dives) == 0.75)
		// Bottom time weighs differently: 1,800s of 3,600s.
		#expect(air.share(of: ring, for: .bottomTime) == 0.5)
		// No trips anywhere, so no share rather than a division by zero.
		#expect(air.share(of: ring, for: .trips) == 0)
	}

	@Test func sliceAtCumulativeValueWalksTheRing() {
		let slices = [
			MetricDonutSlice(id: "a", label: "A", dives: makeDives(2), paletteSlot: 0),
			MetricDonutSlice(id: "b", label: "B", dives: makeDives(3), paletteSlot: 1),
			MetricDonutSlice(id: "c", label: "C", dives: makeDives(5), paletteSlot: 2)
		]
		let lookup = { (value: Double) in
			MetricDonutSlice.slice(atCumulativeValue: value, in: slices, metric: .dives)?.id
		}

		#expect(lookup(0) == "a")
		#expect(lookup(1.5) == "a")
		#expect(lookup(2.5) == "b")
		#expect(lookup(9.9) == "c")
		#expect(lookup(10) == "c")
		#expect(lookup(10.1) == nil)
		#expect(lookup(-1) == nil)
	}
}
