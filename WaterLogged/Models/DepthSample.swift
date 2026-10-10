//
//  DepthSample.swift
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

/// A single time/depth data point from a dive computer profile.
@Model
final class DepthSample {
	var elapsedSeconds: Int = 0
	var depthMeters: Double = 0
	var waterTempCelsius: Double?

	// Tank pressure (bar) — primary and secondary tanks
	var tankPressureBar: Double?
	var tank2PressureBar: Double?

	// Partial pressure of oxygen (bar) — up to 3 sensors
	var ppo2Bar: Double?
	var ppo2Sensor2Bar: Double?
	var ppo2Sensor3Bar: Double?

	// CNS oxygen toxicity (0–100 percentage)
	var cnsPercent: Double?

	// Setpoint (bar) — rebreather PO2 setpoint
	var setpointBar: Double?

	// Decompression status. `decoType` is the persisted raw value, kept as a
	// String so profiles written by earlier builds keep loading; read and write
	// it through `decoStatus` rather than matching on the string directly.
	var decoType: String?
	var decoTimeSeconds: Int?
	var decoDepthMeters: Double?
	var decoTTSSeconds: Int?

	// Remaining bottom time (seconds)
	var rbtSeconds: Int?

	// Heart rate (beats per minute)
	var heartbeatBPM: Int?

	// Compass bearing (degrees)
	var bearingDegrees: Int?

	/// LEGACY — read only by `GasSwitchMigration`, which converts it to
	/// `activeGasMix` and clears it. Its meaning depended on where the sample
	/// came from (a dive computer's slot list, or a UDDF file's mix order), so
	/// it could not be resolved reliably. Remove once every device has run the
	/// conversion, before the CloudKit schema is deployed to Production.
	var activeGasMixIndex: Int?

	/// The gas the diver switched to at this sample; `nil` when no switch
	/// happened here. Switches are sparse, so only a few samples per dive
	/// carry a value.
	var activeGasMix: GasMix?

	// Events (human-readable descriptions)
	var events: [String]?

	@Relationship(deleteRule: .nullify, inverse: \Dive.diveProfile)
	var dive: Dive?

	/// The sample's decompression state, normalized across import sources.
	///
	/// `nil` when nothing was stored or when the stored value predates `DecoType`
	/// and can't be recognized; both mean the sample carries no deco information.
	var decoStatus: DecoType? {
		get { decoType.flatMap { DecoType(importedValue: $0) } }
		set { decoType = newValue?.rawValue }
	}

	init(
		elapsedSeconds: Int,
		depthMeters: Double,
		waterTempCelsius: Double? = nil,
		tankPressureBar: Double? = nil,
		tank2PressureBar: Double? = nil,
		ppo2Bar: Double? = nil,
		ppo2Sensor2Bar: Double? = nil,
		ppo2Sensor3Bar: Double? = nil,
		cnsPercent: Double? = nil,
		setpointBar: Double? = nil,
		decoStatus: DecoType? = nil,
		decoTimeSeconds: Int? = nil,
		decoDepthMeters: Double? = nil,
		decoTTSSeconds: Int? = nil,
		rbtSeconds: Int? = nil,
		heartbeatBPM: Int? = nil,
		bearingDegrees: Int? = nil,
		activeGasMix: GasMix? = nil,
		events: [String]? = nil
	) {
		self.elapsedSeconds = elapsedSeconds
		self.depthMeters = depthMeters
		self.waterTempCelsius = waterTempCelsius
		self.tankPressureBar = tankPressureBar
		self.tank2PressureBar = tank2PressureBar
		self.ppo2Bar = ppo2Bar
		self.ppo2Sensor2Bar = ppo2Sensor2Bar
		self.ppo2Sensor3Bar = ppo2Sensor3Bar
		self.cnsPercent = cnsPercent
		self.setpointBar = setpointBar
		self.decoType = decoStatus?.rawValue
		self.decoTimeSeconds = decoTimeSeconds
		self.decoDepthMeters = decoDepthMeters
		self.decoTTSSeconds = decoTTSSeconds
		self.rbtSeconds = rbtSeconds
		self.heartbeatBPM = heartbeatBPM
		self.bearingDegrees = bearingDegrees
		self.activeGasMix = activeGasMix
		self.events = events
	}
}
