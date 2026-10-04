//
//  UnitSystem.swift
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

enum UnitSystem: String, CaseIterable, Identifiable {
	case metric
	case imperial

	var id: String { rawValue }

	var displayName: String {
		switch self {
			case .metric:   return "Metric"
			case .imperial: return "Imperial"
		}
	}
}

/// Centralised helper for converting metric-stored values to/from the user's preferred unit system.
struct UnitFormatter {
	let system: UnitSystem

	// MARK: - Depth (meters ↔ feet)

	var depthLabel: String { system == .metric ? "m" : "ft" }
	var depthFieldLabel: String { system == .metric ? "Max Depth (m)" : "Max Depth (ft)" }
	var avgDepthFieldLabel: String { system == .metric ? "Avg Depth (m)" : "Avg Depth (ft)" }

	func depthForDisplay(_ meters: Double) -> Double {
		system == .metric ? meters : meters * 3.28084
	}

	func depthToMetric(_ display: Double) -> Double {
		system == .metric ? display : display / 3.28084
	}

	func depthString(_ meters: Double, decimals: Int = 0) -> String {
		let value = depthForDisplay(meters)
		return "\(value.formatted(.number.precision(.fractionLength(decimals)))) \(depthLabel)"
	}

	var visibilityFieldLabel: String { system == .metric ? "Visibility (m)" : "Visibility (ft)" }

	func visibilityString(_ meters: Double, decimals: Int = 0) -> String {
		let value = depthForDisplay(meters)
		return "\(value.formatted(.number.precision(.fractionLength(decimals)))) \(depthLabel)"
	}

	// MARK: - Temperature (°C ↔ °F)

	var tempLabel: String { system == .metric ? "°C" : "°F" }
	var waterTempFieldLabel: String { system == .metric ? "Water Temp (°C)" : "Water Temp (°F)" }
	var airTempFieldLabel: String { system == .metric ? "Air Temp (°C)" : "Air Temp (°F)" }

	func tempForDisplay(_ celsius: Double) -> Double {
		system == .metric ? celsius : celsius * 9.0 / 5.0 + 32.0
	}

	func tempToMetric(_ display: Double) -> Double {
		system == .metric ? display : (display - 32.0) * 5.0 / 9.0
	}

	func tempString(_ celsius: Double, decimals: Int = 1) -> String {
		let value = tempForDisplay(celsius)
		return "\(value.formatted(.number.precision(.fractionLength(decimals))))\(tempLabel)"
	}

	// MARK: - Pressure (bar ↔ PSI)

	var pressureLabel: String { system == .metric ? "bar" : "PSI" }
	var startPressureFieldLabel: String { system == .metric ? "Start Pressure (bar)" : "Start Pressure (PSI)" }
	var endPressureFieldLabel: String { system == .metric ? "End Pressure (bar)" : "End Pressure (PSI)" }

	func pressureForDisplay(_ bar: Double) -> Double {
		system == .metric ? bar : bar * 14.5038
	}

	func pressureToMetric(_ display: Double) -> Double {
		system == .metric ? display : display / 14.5038
	}

	func pressureString(_ bar: Double, decimals: Int = 0) -> String {
		let value = pressureForDisplay(bar)
		return "\(value.formatted(.number.precision(.fractionLength(decimals)))) \(pressureLabel)"
	}

	// MARK: - Weight (kg ↔ lbs)

	var weightLabel: String { system == .metric ? "kg" : "lbs" }
	var weightFieldLabel: String { system == .metric ? "Weight (kg)" : "Weight (lbs)" }

	func weightForDisplay(_ kg: Double) -> Double {
		system == .metric ? kg : kg * 2.20462
	}

	func weightToMetric(_ display: Double) -> Double {
		system == .metric ? display : display / 2.20462
	}

	func weightString(_ kg: Double, decimals: Int = 0) -> String {
		let value = weightForDisplay(kg)
		return "\(value.formatted(.number.precision(.fractionLength(decimals)))) \(weightLabel)"
	}

	// MARK: - Tank Volume (liters ↔ cubic feet)

	var volumeLabel: String { system == .metric ? "L" : "cuft" }
	var tankVolumeFieldLabel: String { system == .metric ? "Tank Volume (L)" : "Tank Volume (cuft)" }

	func volumeForDisplay(_ liters: Double) -> Double {
		system == .metric ? liters : liters * 0.0353147
	}

	func volumeToMetric(_ display: Double) -> Double {
		system == .metric ? display : display / 0.0353147
	}

	func volumeString(_ liters: Double, decimals: Int = 0) -> String {
		let value = volumeForDisplay(liters)
		return "\(value.formatted(.number.precision(.fractionLength(decimals)))) \(volumeLabel)"
	}
}
