//
//  DiveComputerTypes.swift
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

// MARK: - Parsed Data Types

/// Intermediate representation of a dive downloaded from a dive computer.
/// libdivecomputer produces these; the importer maps them to SwiftData models.
struct ParsedDiveData: Sendable {
	var dateTime: Date
	var durationSeconds: Int
	var maxDepthMeters: Double
	var avgDepthMeters: Double
	var waterTempCelsius: Double?
	var samples: [ParsedSampleData]
	var gasMixes: [ParsedGasMixData]
	var diveNumber: Int?
	var computerModel: String
	var serialNumber: String?

	/// libdivecomputer's opaque per-dive identifier, as handed to the dive
	/// callback. Its size and meaning are backend-specific (for Oceanic it is
	/// the raw log book entry), so it is only ever compared or handed straight
	/// back to `dc_device_set_fingerprint` — never interpreted.
	var fingerprint: Data?
}

/// The outcome of one download session, including the byte counts libdivecomputer
/// reported so an incremental download can be compared against a full one.
struct DiveDownloadResult: Sendable {
	var dives: [ParsedDiveData]
	/// The device serial from `DC_EVENT_DEVINFO`, when the backend emits it.
	var serial: UInt32?
	var bytesReceived: Int
	var bytesExpected: Int
}

/// A single time/depth sample from a dive computer profile.
struct ParsedSampleData: Sendable {
	var elapsedSeconds: Int
	var depthMeters: Double
	var waterTempCelsius: Double?

	// Tank pressure (bar) — tank 0 (primary) and tank 1 (secondary/sidemount)
	var tankPressureBar: Double?
	var tank2PressureBar: Double?

	// Partial pressure of oxygen (bar) — up to 3 sensors for rebreather support
	var ppo2Bar: Double?
	var ppo2Sensor2Bar: Double?
	var ppo2Sensor3Bar: Double?

	// CNS oxygen toxicity (0–100 percentage)
	var cnsPercent: Double?

	// Setpoint (bar) — rebreather PO2 setpoint
	var setpointBar: Double?

	// Decompression status
	var decoType: DecoType?        // normalized from dc_deco_type_t
	var decoTimeSeconds: Int?      // time remaining at the stop
	var decoDepthMeters: Double?   // ceiling/stop depth
	var decoTTSSeconds: Int?       // total time to surface

	// Remaining bottom time (seconds)
	var rbtSeconds: Int?

	// Heart rate (beats per minute)
	var heartbeatBPM: Int?

	// Compass bearing (degrees)
	var bearingDegrees: Int?

	// Active gas mix index (references ParsedDiveData.gasMixes)
	var activeGasMixIndex: Int?

	// Events (human-readable descriptions)
	var events: [String]?
}

/// A gas mix configuration from a dive computer.
struct ParsedGasMixData: Sendable {
	var oxygenPercent: Double
	var heliumPercent: Double
	var name: String?
}

// MARK: - Progress

/// Reports transfer progress from the download handler to the UI.
enum TransferProgress: Sendable, Equatable {
	case connecting
	case discoveringServices
	case handshaking
	/// Transferring dive data from the device with byte-level progress.
	case transferring(bytesReceived: Int, totalBytes: Int)
	/// Parsing a specific dive after all data has been transferred.
	case parsingDive(current: Int, total: Int)
	case complete(diveCount: Int)
}

// MARK: - Errors

/// Errors specific to dive computer protocol communication.
enum DiveComputerError: LocalizedError, Sendable {
	case protocolError(String)
	case unsupportedModel(String)
	case noDataAvailable
	case cancelled

	var errorDescription: String? {
		switch self {
			case .protocolError(let detail):
				"Protocol error: \(detail)"
			case .unsupportedModel(let model):
				"Unsupported dive computer model: \(model)"
			case .noDataAvailable:
				"No dive data available on this computer."
			case .cancelled:
				"Transfer was cancelled."
		}
	}
}
