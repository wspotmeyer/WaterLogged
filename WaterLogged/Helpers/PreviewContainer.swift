//
//  PreviewContainer.swift
//  WaterLogged
//
//  Created by John Meyer on 2/23/26.
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

import SwiftData
import Foundation

@MainActor
struct PreviewContainer {
	static let container: ModelContainer = {
		let schema = Schema([Dive.self, DiveSite.self, GasMix.self, DepthSample.self, Equipment.self, ServiceRecord.self, Certification.self, Buddy.self, Trip.self, LogbookOwner.self, Photo.self, Tank.self])
		// Explicitly local: the default `.automatic` would start CloudKit
		// mirroring on this in-memory store now that the app has the iCloud
		// entitlement, which breaks the store.
		let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
		// swiftlint:disable:next force_try
		let container = try! ModelContainer(for: schema, configurations: config)
		insertSampleData(into: container)
		return container
	}()

	static func insertSampleData(into container: ModelContainer) {
		let context = container.mainContext

		let site1 = DiveSite(name: "Palancar Reef", country: "Mexico", region: "Cozumel",
							 latitude: 20.3005, longitude: -87.0196, notes: "World-class wall dive")
		let site2 = DiveSite(name: "Blue Corner", country: "Palau", region: "Ngeremlengui",
							 latitude: 7.1513, longitude: 134.3627, notes: "Famous drift dive")
		let site3 = DiveSite(name: "SS Thistlegorm", country: "Egypt", region: "Red Sea",
							 latitude: 27.8133, longitude: 32.6456, notes: "WWII wreck")
		context.insert(site1)
		context.insert(site2)
		context.insert(site3)

		let gas1 = GasMix(name: "EAN32", oxygenPercent: 32, heliumPercent: 0)
		let gas2 = GasMix(name: "Air", oxygenPercent: 21, heliumPercent: 0)
		context.insert(gas1)
		context.insert(gas2)

		let dive1 = Dive(
			diveNumber: 142, date: .now, title: "Palancar Caves",
			maxDepthMeters: 28.4, durationSeconds: 3120,
			waterTempCelsius: 27.0, airTempCelsius: 30.0,
			visibilityMeters: 25, waterType: .salt, current: .slight, waveConditions: .calm,
			weather: "Sunny", suitType: .wetsuit3mm, weightKg: 4.0,
			diveGuide: "Carlos", diveOperator: "Scuba Club Cozumel", diveBoat: nil,
			rating: 5, notes: "Absolutely stunning swimthroughs. Spotted a huge eagle ray near the sand at 28m.",
			tags: ["reef", "swimthrough", "eagle ray"], importSource: "Manual", site: site1
		)
		let dive2 = Dive(
			diveNumber: 141, date: Calendar.current.date(byAdding: .day, value: -35, to: .now)!,
			title: "Palancar Bricks",
			maxDepthMeters: 18.0, durationSeconds: 2700,
			waterTempCelsius: 27.5, airTempCelsius: 29.0,
			visibilityMeters: 15, waterType: .salt, waveConditions: .calm,
			weather: "Partly cloudy", suitType: .wetsuit3mm, weightKg: 4.0,
			diveOperator: "Scuba Club Cozumel",
			rating: 4, notes: "Nice shallow dive. Lots of coral formations.",
			tags: ["reef", "coral"], importSource: "Manual", site: site1
		)
		let dive3 = Dive(
			diveNumber: 140, date: Calendar.current.date(byAdding: .day, value: -70, to: .now)!,
			title: "Blue Corner Wall",
			maxDepthMeters: 32.1, durationSeconds: 2580,
			waterTempCelsius: 29.0, airTempCelsius: 32.0,
			visibilityMeters: 30, waterType: .salt, current: .strong, waveConditions: .slight,
			weather: "Sunny", suitType: .rashguard, weightKg: 2.0,
			diveGuide: "Tomas", diveOperator: "Sam's Tours",
			diveBoat: nil,
			rating: 5, notes: "Incredible drift. Schooling barracuda and a grey reef shark.",
			tags: ["drift", "shark", "pelagic"], importSource: "Manual", site: site2
		)
		let dive4 = Dive(
			diveNumber: 139, date: Calendar.current.date(byAdding: .month, value: -3, to: .now)!,
			title: "Thistlegorm Bow",
			maxDepthMeters: 24.0, durationSeconds: 2400,
			waterTempCelsius: 24.0, airTempCelsius: 28.0,
			visibilityMeters: 12, waterType: .salt, current: .moderate, waveConditions: .slight,
			weather: "Clear", suitType: .wetsuit5mm, weightKg: 6.0,
			diveOperator: "Red Sea Diving",
			rating: 5, notes: "Explored the locomotive carriages.",
			tags: ["wreck", "history"], importSource: "Manual", site: site3
		)
		let dive5 = Dive(
			diveNumber: 138, date: Calendar.current.date(byAdding: .month, value: -3, to: .now)!,
			title: "Thistlegorm Stern",
			maxDepthMeters: 28.5, durationSeconds: 2700,
			waterTempCelsius: 23.5, airTempCelsius: 27.0,
			visibilityMeters: 8, waterType: .salt, current: .slight, waveConditions: .calm,
			weather: "Sunny", suitType: .wetsuit5mm, weightKg: 6.0,
			diveOperator: "Red Sea Diving",
			rating: 4, notes: "Great stern section with anti-aircraft guns.",
			tags: ["wreck"], importSource: "Manual", site: site3
		)
		let dive6 = Dive(
			diveNumber: 137, date: Calendar.current.date(byAdding: .month, value: -4, to: .now)!,
			title: "Shark City",
			maxDepthMeters: 30.0, durationSeconds: 2340,
			waterTempCelsius: 29.0, airTempCelsius: 31.0,
			visibilityMeters: 30, waterType: .salt, current: .strong, waveConditions: .moderate,
			weather: "Partly cloudy", suitType: .rashguard, weightKg: 2.0,
			diveGuide: "Tomas", diveOperator: "Sam's Tours",
			diveBoat: nil,
			rating: 5, notes: "Multiple grey reef sharks at the cleaning station.",
			tags: ["shark", "pelagic", "drift"], importSource: "Manual", site: site2
		)
		context.insert(dive1)
		context.insert(dive2)
		context.insert(dive3)
		context.insert(dive4)
		context.insert(dive5)
		context.insert(dive6)

		// Tanks — one tank per dive linked to its gas mix
		for (dive, gas) in [(dive1, gas1), (dive2, gas1), (dive3, gas2), (dive4, gas2), (dive5, gas2), (dive6, gas2)] {
			let tank = Tank(gasMix: gas, startPressureBar: 200, endPressureBar: 60)
			tank.dive = dive
			context.insert(tank)
		}

		// Trips
		let trip1 = Trip(
			name: "Cozumel Spring Trip",
			startDate: Calendar.current.date(byAdding: .day, value: -2, to: .now)!,
			endDate: Calendar.current.date(byAdding: .day, value: 5, to: .now)!,
			location: "Cozumel, Mexico",
			address: "Cozumel, Quintana Roo, Mexico",
			latitude: 20.4318,
			longitude: -86.9203,
			notes: "Spring diving trip."
		)
		let trip2 = Trip(
			name: "Palau Adventure",
			startDate: Calendar.current.date(byAdding: .day, value: -72, to: .now)!,
			endDate: Calendar.current.date(byAdding: .day, value: -65, to: .now)!,
			location: "Koror, Palau",
			latitude: 7.3419,
			longitude: 134.4789,
			notes: "World-class diving in Palau."
		)
		let trip3 = Trip(
			name: "Red Sea Liveaboard",
			startDate: Calendar.current.date(byAdding: .month, value: -3, to: .now)!,
			endDate: Calendar.current.date(byAdding: .day, value: 7, to: Calendar.current.date(byAdding: .month, value: -3, to: .now)!)!,
			location: "Sharm el-Sheikh, Egypt",
			latitude: 27.9158,
			longitude: 34.3300,
			notes: "Liveaboard wreck diving trip."
		)
		context.insert(trip1)
		context.insert(trip2)
		context.insert(trip3)

		// Assign dives to trips
		dive1.trip = trip1
		dive2.trip = trip1
		dive3.trip = trip2
		dive6.trip = trip2
		dive4.trip = trip3
		dive5.trip = trip3

		// Depth profile for dive1 — multilevel reef dive
		let reefProfile: [(Int, Double)] = [
			(0, 0), (30, 3), (60, 8), (120, 15), (180, 22), (240, 28), (300, 28.4),
			(600, 28), (900, 25), (1200, 20), (1800, 18), (2400, 15), (2880, 8), (3060, 3), (3120, 0)
		]
		for (t, d) in reefProfile {
			let sample = DepthSample(elapsedSeconds: t, depthMeters: d, waterTempCelsius: 27.0)
			sample.dive = dive1
			context.insert(sample)
		}

		// Depth profile for dive4 — square wreck dive
		let wreckProfile: [(Int, Double)] = [
			(0, 0), (60, 5), (120, 15), (180, 24), (240, 24),
			(600, 24), (1200, 24), (1800, 23), (2100, 15), (2400, 5), (2580, 0)
		]
		for (t, d) in wreckProfile {
			let sample = DepthSample(elapsedSeconds: t, depthMeters: d, waterTempCelsius: 24.0)
			sample.dive = dive4
			context.insert(sample)
		}
	}
}
