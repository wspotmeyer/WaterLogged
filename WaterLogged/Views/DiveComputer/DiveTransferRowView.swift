//
//  DiveTransferRowView.swift
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

import SwiftUI

struct DiveTransferRowView: View {
	let dive: ParsedDiveData

	@AppStorage("unitSystem") private var unitSystem: String = UnitSystem.imperial.rawValue

	private var formatter: UnitFormatter {
		UnitFormatter(system: UnitSystem(rawValue: unitSystem) ?? .metric)
	}

	var body: some View {
		HStack {
			VStack(alignment: .leading) {
				HStack {
					if let num = dive.diveNumber {
						Text("#\(num)")
							.font(.headline)
					}
					Text(dive.dateTime.formatted(date: .abbreviated, time: .shortened))
						.font(.headline)
				}

				HStack(spacing: 16) {
					Label(formatter.depthString(dive.maxDepthMeters), systemImage: "arrow.down.to.line")
					Label(
						Duration.seconds(dive.durationSeconds).formatted(
							.time(pattern: .minuteSecond(padMinuteToLength: 1))
						),
						systemImage: "clock"
					)
					if let temp = dive.waterTempCelsius {
						Label(formatter.tempString(temp), systemImage: "thermometer.medium")
					}
				}
				.font(.subheadline)
				.foregroundStyle(.secondary)
			}

			Spacer()

			if !dive.gasMixes.isEmpty {
				Text(dive.gasMixes.map { $0.name ?? "Mix" }.joined(separator: ", "))
					.font(.caption)
					.foregroundStyle(.secondary)
			}
		}
	}
}
