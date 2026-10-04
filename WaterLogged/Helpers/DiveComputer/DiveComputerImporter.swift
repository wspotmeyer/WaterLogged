//
//  DiveComputerImporter.swift
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

import Foundation
import SwiftData

/// Imports parsed dive computer data into the SwiftData model context.
///
/// This importer takes the `ParsedDiveData` produced by `LibDCDeviceHandler` and
/// creates the corresponding `Dive`, `DepthSample`, and `GasMix` SwiftData models.
struct DiveComputerImporter {

	/// Import an array of parsed dives into the given model context.
	///
	/// Dives are sorted by date and assigned consecutive dive numbers
	/// starting after the highest existing dive number in the database.
	/// Returns the number of dives imported.
	@discardableResult
	static func importDives(
		_ parsedDives: [ParsedDiveData],
		into context: ModelContext
	) throws -> Int {
		// Find the current maximum dive number in the database
		var descriptor = FetchDescriptor<Dive>(
			sortBy: [SortDescriptor(\.diveNumber, order: .reverse)]
		)
		descriptor.fetchLimit = 1
		let maxExisting = (try? context.fetch(descriptor))?.first?.diveNumber ?? 0

		// Sort imported dives by date so numbering follows chronological order
		let sorted = parsedDives.sorted { $0.dateTime < $1.dateTime }

		var nextNumber = maxExisting + 1
		var importedCount = 0

		for parsed in sorted {
			let dive = mapDive(parsed, diveNumber: nextNumber)
			context.insert(dive)

			// Create a Tank only for the gas mix slots that represent a tank the
			// diver actually used. Dive computers report every gas slot they can be
			// configured with, so importing all of them produces phantom tanks
			// with no pressure data — see DiveComputerTankFilter.
			for index in DiveComputerTankFilter.tankGasMixIndices(for: parsed) {
				let parsedGas = parsed.gasMixes[index]
				let tankGasMix = GasMix.findOrCreate(
					name: parsedGas.name ?? gasLabel(o2: parsedGas.oxygenPercent, he: parsedGas.heliumPercent),
					oxygenPercent: parsedGas.oxygenPercent,
					heliumPercent: parsedGas.heliumPercent,
					in: context
				)

				let pressures = DiveComputerTankFilter.pressures(
					forGasMixIndex: index,
					in: parsed
				)

				let tank = Tank(
					gasMix: tankGasMix,
					startPressureBar: pressures.start,
					endPressureBar: pressures.end
				)
				tank.dive = dive
				context.insert(tank)
			}

			// Insert depth profile samples
			for sample in parsed.samples {
				let depthSample = DepthSample(
					elapsedSeconds: sample.elapsedSeconds,
					depthMeters: sample.depthMeters,
					waterTempCelsius: sample.waterTempCelsius,
					tankPressureBar: sample.tankPressureBar,
					tank2PressureBar: sample.tank2PressureBar,
					ppo2Bar: sample.ppo2Bar,
					ppo2Sensor2Bar: sample.ppo2Sensor2Bar,
					ppo2Sensor3Bar: sample.ppo2Sensor3Bar,
					cnsPercent: sample.cnsPercent,
					setpointBar: sample.setpointBar,
					decoStatus: sample.decoType,
					decoTimeSeconds: sample.decoTimeSeconds,
					decoDepthMeters: sample.decoDepthMeters,
					decoTTSSeconds: sample.decoTTSSeconds,
					rbtSeconds: sample.rbtSeconds,
					heartbeatBPM: sample.heartbeatBPM,
					bearingDegrees: sample.bearingDegrees,
					activeGasMixIndex: sample.activeGasMixIndex,
					events: sample.events
				)
				depthSample.dive = dive
				context.insert(depthSample)
			}

			nextNumber += 1
			importedCount += 1
		}

		if importedCount > 0 {
			try context.save()
		}

		return importedCount
	}

	// MARK: - Mapping

	private static func mapDive(
		_ parsed: ParsedDiveData,
		diveNumber: Int
	) -> Dive {
		// Water temperature from the dive computer or average of sample temps
		let waterTemp: Double? = parsed.waterTempCelsius ?? {
			let temps = parsed.samples.compactMap(\.waterTempCelsius)
			guard !temps.isEmpty else { return nil }
			return temps.reduce(0, +) / Double(temps.count)
		}()

		let dive = Dive(
			diveNumber: diveNumber,
			date: parsed.dateTime,
			title: "Dive #\(diveNumber)",
			maxDepthMeters: parsed.maxDepthMeters,
			durationSeconds: parsed.durationSeconds,
			waterTempCelsius: waterTemp,
			rating: 0,
			importSource: parsed.computerModel
		)

		return dive
	}

	private static func gasLabel(o2: Double, he: Double) -> String {
		if he > 0 {
			return "Trimix \(Int(o2))/\(Int(he))"
		} else if Int(o2) == 21 {
			return "Air"
		} else {
			return "EAN\(Int(o2))"
		}
	}
}
