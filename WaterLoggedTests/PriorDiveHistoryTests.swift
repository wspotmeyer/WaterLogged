//
//  PriorDiveHistoryTests.swift
//  WaterLoggedTests
//
//  Created by John Meyer on 9/25/26.
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
@testable import WaterLogged

struct PriorDiveHistoryTests {

	@Test func noneLeavesTotalsUnchanged() {
		#expect(PriorDiveHistory.none.totalDives(logged: 12) == 12)
		#expect(PriorDiveHistory.none.totalBottomTimeSeconds(logged: 3600) == 3600)
	}

	@Test func addsPriorValuesToLoggedTotals() {
		let history = PriorDiveHistory(diveCount: 150, bottomTimeMinutes: 90)
		#expect(history.totalDives(logged: 12) == 162)
		#expect(history.bottomTimeSeconds == 5400)
		#expect(history.totalBottomTimeSeconds(logged: 3600) == 9000)
	}

	@Test func negativeValuesAreTreatedAsZero() {
		let history = PriorDiveHistory(diveCount: -5, bottomTimeMinutes: -30)
		#expect(history.totalDives(logged: 3) == 3)
		#expect(history.totalBottomTimeSeconds(logged: 600) == 600)
	}

	@Test func splitsIntoHoursAndMinutes() {
		let history = PriorDiveHistory(bottomTimeMinutes: 125)
		#expect(history.bottomTimeHoursComponent == 2)
		#expect(history.bottomTimeMinutesComponent == 5)
	}

	@Test func settingHoursKeepsMinutes() {
		var history = PriorDiveHistory(bottomTimeMinutes: 125)
		history.bottomTimeHoursComponent = 10
		#expect(history.bottomTimeMinutes == 605)
	}

	@Test func settingMinutesKeepsHoursAndRollsOver() {
		var history = PriorDiveHistory(bottomTimeMinutes: 125)
		history.bottomTimeMinutesComponent = 90
		#expect(history.bottomTimeMinutes == 210)
		#expect(history.bottomTimeHoursComponent == 3)
		#expect(history.bottomTimeMinutesComponent == 30)
	}
}
