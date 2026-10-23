//
//  YearlyStatValueTests.swift
//  WaterLogged
//
//  Created by John Meyer on 10/23/26.
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
struct YearlyStatValueTests {

	private let calendar: Calendar = {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = .gmt
		return calendar
	}()

	private func date(_ year: Int, _ month: Int = 6) -> Date {
		calendar.date(from: DateComponents(year: year, month: month, day: 15)) ?? .distantPast
	}

	@Test func groupsDivesByYearOldestFirst() {
		let trip = Trip(name: "Cozumel", startDate: .distantPast, endDate: .distantPast)
		let dives = [
			Dive(date: date(2024, 3), durationSeconds: 1_800, trip: trip),
			Dive(date: date(2022), durationSeconds: 3_000),
			Dive(date: date(2024, 11), durationSeconds: 2_400, trip: trip)
		]

		let years = YearlyStatValue.grouped(dives, calendar: calendar)

		#expect(years.map { calendar.component(.year, from: $0.year) } == [2022, 2024])
		#expect(years.map { $0.value(for: .dives) } == [1, 2])
		#expect(years.map { $0.value(for: .bottomTime) } == [3_000, 4_200])
		// Two 2024 dives on the same trip count it once; 2022's dive has none.
		#expect(years.map { $0.value(for: .trips) } == [0, 1])
	}

	@Test func tripOverNewYearCountsInBothYears() {
		let trip = Trip(name: "Bonaire", startDate: .distantPast, endDate: .distantPast)
		let dives = [
			Dive(date: date(2024, 12), trip: trip),
			Dive(date: date(2025, 1), trip: trip)
		]

		let years = YearlyStatValue.grouped(dives, calendar: calendar)

		#expect(years.map { $0.value(for: .trips) } == [1, 1])
	}

	@Test func groupsNoDives() {
		#expect(YearlyStatValue.grouped([], calendar: calendar).isEmpty)
	}

	@Test func descriptorSummarizesTheBusiestYearForEachMetric() {
		let trip = Trip(name: "Cozumel", startDate: .distantPast, endDate: .distantPast)
		let years = [
			YearlyStatValue(year: date(2020), dives: [Dive(durationSeconds: 36_000, trip: trip)]),
			YearlyStatValue(year: date(2021), dives: [Dive(durationSeconds: 600), Dive(durationSeconds: 600)])
		]
		let summary = { (metric: StatMetric) in
			DivesPerYearChartDescriptor(years: years, metric: metric).summary
		}

		#expect(summary(.dives).contains("most dives in 2021"))
		#expect(summary(.bottomTime).contains("most bottom time in 2020"))
		#expect(summary(.trips).contains("most trips in 2020"))
	}

	@Test func descriptorSaysWhenAMetricIsEmpty() {
		let years = [YearlyStatValue(year: date(2020), dives: [Dive()])]

		#expect(DivesPerYearChartDescriptor(years: years, metric: .trips).summary == "No trips")
		#expect(DivesPerYearChartDescriptor(years: [], metric: .dives).summary == "No dives")
	}

	@Test func axisStrideStaysWholeForCounts() {
		#expect(StatMetric.trips.axisStride(forLargest: 2) == 1)
		#expect(StatMetric.dives.axisStride(forLargest: 80) == 20)
		#expect(StatMetric.bottomTime.axisStride(forLargest: 2) == 0.5)
		#expect(StatMetric.dives.axisStride(forLargest: 0) == 1)
	}
}
