//
//  DepthProfileChart.swift
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
import SwiftData
import Charts

struct DepthProfileChart: View {
	let samples: [DepthSample]
	var diveStartTime: Date?
	@AppStorage("unitSystem") private var unitSystem: UnitSystem = .imperial

	// Overlay toggle states — depth is always shown
	@State private var showTemperature = false
	@State private var showTankPressure = true
	@State private var showPPO2 = false
	@State private var showCNS = false
	@State private var showDecoType = false
	@State private var showDecoTime = false
	@State private var showDecoDepth = false
	@State private var showRBT = false

	// Interactive selection
	@State private var rawSelectedTime: Double?
	@Environment(\.colorScheme) private var colorScheme

	private var units: UnitFormatter { UnitFormatter(system: unitSystem) }
	private var indicatorBrightness: Double { colorScheme == .dark ? 0.3 : 0.8 }

	/// Finds the sample closest to the raw selected time (in minutes).
	private func selectedSample(in data: ChartData) -> DepthSample? {
		guard let rawSelectedTime else { return nil }
		return data.sortedSamples.min(by: {
			abs(Double($0.elapsedSeconds) / 60.0 - rawSelectedTime) <
				abs(Double($1.elapsedSeconds) / 60.0 - rawSelectedTime)
		})
	}

	/// Pre-computed chart data derived from samples and the current unit system.
	private var chartData: ChartData {
		let sorted = samples.sorted { $0.elapsedSeconds < $1.elapsedSeconds }

		let maxDisplayDepth = sorted.map { units.depthForDisplay($0.depthMeters) }.max() ?? 1
		let maxTime = sorted.last.map { Double($0.elapsedSeconds) / 60.0 } ?? 1

		// Collect display-unit values for each overlay to compute ranges
		let temps = sorted.compactMap { $0.waterTempCelsius }.map { units.tempForDisplay($0) }
		let pressures = sorted.compactMap { $0.tankPressureBar }.map { units.pressureForDisplay($0) }
		let ppo2s = sorted.compactMap { $0.ppo2Bar }
		let cnss = sorted.compactMap { $0.cnsPercent }
		let decoTimes = sorted.compactMap { $0.decoTimeSeconds }.map { Double($0) / 60.0 }
		let decoDepths = sorted.compactMap { $0.decoDepthMeters }.map { units.depthForDisplay($0) }
		let rbts = sorted.compactMap { $0.rbtSeconds }.map { Double($0) / 60.0 }

		return ChartData(
			sortedSamples: sorted,
			maxDisplayDepth: maxDisplayDepth,
			maxTime: maxTime,
			hasTemperature: !temps.isEmpty,
			hasTankPressure: !pressures.isEmpty,
			hasPPO2: !ppo2s.isEmpty,
			hasCNS: !cnss.isEmpty,
			hasDecoType: sorted.contains { $0.decoStatus != nil },
			hasDecoTime: !decoTimes.isEmpty,
			hasDecoDepth: !decoDepths.isEmpty,
			hasRBT: !rbts.isEmpty,
			tempRange: Self.paddedRange(temps, minSpan: 1.0),
			pressureRange: OverlayRange(
				min: 0,
				max: (pressures.max() ?? 1) * 1.1
			),
			ppo2Range: Self.paddedRange(ppo2s, minSpan: 0.1),
			cnsRange: OverlayRange(
				min: 0,
				max: max((cnss.max() ?? 100) * 1.1, 100)
			),
			decoTimeRange: Self.paddedRange(decoTimes, minSpan: 1.0),
			decoDepthRange: Self.paddedRange(decoDepths, minSpan: 1.0),
			rbtRange: Self.paddedRange(rbts, minSpan: 1.0)
		)
	}

	private static func paddedRange(_ values: [Double], minSpan: Double) -> OverlayRange {
		guard let lo = values.min(), let hi = values.max() else {
			return OverlayRange(min: 0, max: 1)
		}
		let padding = max((hi - lo) * 0.2, minSpan * 0.5)
		return OverlayRange(min: lo - padding, max: hi + padding)
	}

	var body: some View {
		let data = chartData

		VStack(alignment: .leading, spacing: 10) {
			Text("Dive Profile")
				.font(.title2.bold())
			Chart {
				// Depth — always displayed
				ForEach(data.sortedSamples, id: \.elapsedSeconds) { sample in
					let time = Double(sample.elapsedSeconds) / 60.0
					let displayDepth = units.depthForDisplay(sample.depthMeters)

					LineMark(
						x: .value("Time", time),
						y: .value("Depth", -displayDepth),
						series: .value("Series", "Depth")
					)
					.interpolationMethod(.catmullRom)
					.foregroundStyle(.tint)

					AreaMark(
						x: .value("Time", time),
						y: .value("Depth", -displayDepth)
					)
					.interpolationMethod(.catmullRom)
					.foregroundStyle(.tint.opacity(0.15))
				}

				// Temperature
				if showTemperature && data.hasTemperature {
					ForEach(data.sortedSamples.filter { $0.waterTempCelsius != nil }, id: \.elapsedSeconds) { sample in
						let time = Double(sample.elapsedSeconds) / 60.0
						let displayTemp = units.tempForDisplay(sample.waterTempCelsius!)
						let scaled = data.scaleToFullChart(displayTemp, range: data.tempRange)

						LineMark(
							x: .value("Time", time),
							y: .value("Depth", scaled),
							series: .value("Series", "Temperature")
						)
						.interpolationMethod(.catmullRom)
						.foregroundStyle(Self.temperatureColor)
						.lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
					}
				}

				// Tank pressure
				if showTankPressure && data.hasTankPressure {
					ForEach(data.sortedSamples.filter { $0.tankPressureBar != nil }, id: \.elapsedSeconds) { sample in
						let time = Double(sample.elapsedSeconds) / 60.0
						let displayPressure = units.pressureForDisplay(sample.tankPressureBar!)
						let scaled = data.scaleToFullChart(displayPressure, range: data.pressureRange)

						LineMark(
							x: .value("Time", time),
							y: .value("Depth", scaled),
							series: .value("Series", "Tank Pressure")
						)
						.interpolationMethod(.catmullRom)
						.foregroundStyle(Self.tankPressureColor)
						.lineStyle(StrokeStyle(lineWidth: 1.5))
					}
				}

				// PPO₂
				if showPPO2 && data.hasPPO2 {
					ForEach(data.sortedSamples.filter { $0.ppo2Bar != nil }, id: \.elapsedSeconds) { sample in
						let time = Double(sample.elapsedSeconds) / 60.0
						let scaled = data.scaleToFullChart(sample.ppo2Bar!, range: data.ppo2Range)

						LineMark(
							x: .value("Time", time),
							y: .value("Depth", scaled),
							series: .value("Series", "PPO2")
						)
						.interpolationMethod(.catmullRom)
						.foregroundStyle(Self.ppo2Color)
						.lineStyle(StrokeStyle(lineWidth: 1.5))
					}
				}

				// CNS %
				if showCNS && data.hasCNS {
					ForEach(data.sortedSamples.filter { $0.cnsPercent != nil }, id: \.elapsedSeconds) { sample in
						let time = Double(sample.elapsedSeconds) / 60.0
						let scaled = data.scaleToOverlayBand(sample.cnsPercent!, range: data.cnsRange)

						LineMark(
							x: .value("Time", time),
							y: .value("Depth", scaled),
							series: .value("Series", "CNS")
						)
						.interpolationMethod(.catmullRom)
						.foregroundStyle(Self.cnsColor)
						.lineStyle(StrokeStyle(lineWidth: 1.5))
					}
				}

				// Deco status (colored point marks along the depth line)
				if showDecoType && data.hasDecoType {
					ForEach(data.sortedSamples, id: \.elapsedSeconds) { sample in
						if let status = sample.decoStatus {
							let time = Double(sample.elapsedSeconds) / 60.0
							let displayDepth = units.depthForDisplay(sample.depthMeters)

							PointMark(
								x: .value("Time", time),
								y: .value("Depth", -displayDepth)
							)
							.foregroundStyle(Self.decoTypeColor(for: status))
							.symbolSize(20)
						}
					}
				}

				// Deco time
				if showDecoTime && data.hasDecoTime {
					ForEach(data.sortedSamples.filter { $0.decoTimeSeconds != nil }, id: \.elapsedSeconds) { sample in
						let time = Double(sample.elapsedSeconds) / 60.0
						let decoMinutes = Double(sample.decoTimeSeconds!) / 60.0
						let scaled = data.scaleToFullChart(decoMinutes, range: data.decoTimeRange)

						LineMark(
							x: .value("Time", time),
							y: .value("Depth", scaled),
							series: .value("Series", "DecoTime")
						)
						.interpolationMethod(.catmullRom)
						.foregroundStyle(Self.decoTimeColor)
						.lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
					}
				}

				// Deco depth
				if showDecoDepth && data.hasDecoDepth {
					ForEach(data.sortedSamples.filter { $0.decoDepthMeters != nil }, id: \.elapsedSeconds) { sample in
						let time = Double(sample.elapsedSeconds) / 60.0
						let displayDecoDepth = units.depthForDisplay(sample.decoDepthMeters!)
						let scaled = data.scaleToOverlayBand(displayDecoDepth, range: data.decoDepthRange)

						LineMark(
							x: .value("Time", time),
							y: .value("Depth", scaled),
							series: .value("Series", "DecoDepth")
						)
						.interpolationMethod(.catmullRom)
						.foregroundStyle(Self.decoDepthColor)
						.lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
					}
				}

				// RBT (remaining bottom time)
				if showRBT && data.hasRBT {
					ForEach(data.sortedSamples.filter { $0.rbtSeconds != nil }, id: \.elapsedSeconds) { sample in
						let time = Double(sample.elapsedSeconds) / 60.0
						let rbtMinutes = Double(sample.rbtSeconds!) / 60.0
						let scaled = data.scaleToOverlayBand(rbtMinutes, range: data.rbtRange)

						LineMark(
							x: .value("Time", time),
							y: .value("Depth", scaled),
							series: .value("Series", "RBT")
						)
						.interpolationMethod(.catmullRom)
						.foregroundStyle(Self.rbtColor)
						.lineStyle(StrokeStyle(lineWidth: 1.5))
					}
				}

				// Selection indicator
				if let sample = selectedSample(in: data) {
					let time = Double(sample.elapsedSeconds) / 60.0

					RuleMark(x: .value("Selected", time))
						.foregroundStyle(Color.gray.opacity(0.3))
						.zIndex(1)
						.annotation(
							position: .topLeading, spacing: 0,
							overflowResolution: .init(
								x: .fit(to: .chart),
								y: .fit(to: .chart)
							)
						) {
							selectionPopover(for: sample)
						}
				}
			}
			.chartYAxis {
				AxisMarks(position: .leading) { value in
					AxisGridLine()
					AxisValueLabel {
						if let depth = value.as(Double.self) {
							// Primary rather than the default axis gray, which falls below 4.5:1 on the tile.
							// A concrete `Color.primary`: the hierarchical `.primary` resolves against the
							// axis's own gray style and stays gray.
							Text("\(abs(depth).formatted(.number.precision(.fractionLength(0)))) \(units.depthLabel)")
								.foregroundStyle(Color.primary)
						}
					}
				}

				if let axisInfo = soleActiveOverlayAxis(data: data) {
					AxisMarks(position: .trailing, values: overlayAxisValues(data: data, axisInfo: axisInfo)) { value in
						AxisValueLabel {
							if let y = value.as(Double.self) {
								let raw = axisInfo.usesFullChart
								? data.unscaleFromFullChart(y, range: axisInfo.range)
								: data.unscaleFromOverlayBand(y, range: axisInfo.range)
								let display = raw.isZero ? 0.0 : raw
								Text("\(display.formatted(.number.precision(.fractionLength(axisInfo.decimals))))\(axisInfo.suffix)")
									.foregroundStyle(axisInfo.color)
							}
						}
					}
				}
			}
			.chartYScale(domain: -data.maxDisplayDepth...0)
			.chartXScale(domain: 0...data.maxTime)
			.chartXAxis {
				AxisMarks { value in
					AxisGridLine()
					AxisValueLabel {
						if let mins = value.as(Double.self) {
							Text("\(mins.formatted(.number.precision(.fractionLength(0)))) min")
								.foregroundStyle(Color.primary)
						}
					}
				}
			}
			.chartXSelection(value: $rawSelectedTime)
			.chartLegend(.hidden)
			.frame(height: 250)

			overlayToggles(data: data)

#if os(macOS)
			Text("Hover over a point to see details of the sample.")
				.font(.caption)
#else
			Text("Tap on a point to see details of the sample.")
				.font(.caption)
#endif
		}
	}

	// MARK: - Overlay Toggles

	@ViewBuilder
	private func overlayToggles(data: ChartData) -> some View {
		let hasAnyOverlay = data.hasTemperature || data.hasTankPressure || data.hasPPO2
		|| data.hasCNS || data.hasDecoType || data.hasDecoTime
		|| data.hasDecoDepth || data.hasRBT

		if hasAnyOverlay {
			ScrollView(.horizontal) {
				HStack {
					if data.hasTemperature {
						OverlayToggleButton(
							title: "Temperature (\(units.tempLabel))",
							color: Self.temperatureColor,
							isOn: $showTemperature
						)
					}
					if data.hasTankPressure {
						OverlayToggleButton(
							title: "Tank Pressure (\(units.pressureLabel))",
							color: Self.tankPressureColor,
							isOn: $showTankPressure
						)
					}
					if data.hasPPO2 {
						OverlayToggleButton(
							title: "PPO\u{2082} (ata)",
							color: Self.ppo2Color,
							isOn: $showPPO2
						)
					}
					if data.hasCNS {
						OverlayToggleButton(
							title: "CNS (%)",
							color: Self.cnsColor,
							isOn: $showCNS
						)
					}
					if data.hasDecoType {
						OverlayToggleButton(
							title: "Deco Status",
							color: Self.decoTypeToggleColor,
							isOn: $showDecoType
						)
					}
					if data.hasDecoTime {
						OverlayToggleButton(
							title: "Time to Deco (min)",
							color: Self.decoTimeColor,
							isOn: $showDecoTime
						)
					}
					if data.hasDecoDepth {
						OverlayToggleButton(
							title: "Deco Depth (\(units.depthLabel))",
							color: Self.decoDepthColor,
							isOn: $showDecoDepth
						)
					}
					if data.hasRBT {
						OverlayToggleButton(
							title: "RBT (min)",
							color: Self.rbtColor,
							isOn: $showRBT
						)
					}
				}
			}
			.scrollIndicators(.hidden)
		}
	}

	// MARK: - Selection Popover

	private func selectionPopover(for sample: DepthSample) -> some View {
		Grid(alignment: .leading, horizontalSpacing: 4, verticalSpacing: 3) {
			// Time header
			GridRow {
				if let startTime = diveStartTime {
					Text(startTime.addingTimeInterval(Double(sample.elapsedSeconds)), format: .dateTime.hour().minute().second())
						.font(.caption)
						.bold()
						.gridCellColumns(3)
				} else {
					let minutes = sample.elapsedSeconds / 60
					let seconds = sample.elapsedSeconds % 60
					Text("\(minutes):\(seconds, format: .number.precision(.integerLength(2)))")
						.font(.caption)
						.bold()
						.gridCellColumns(3)
				}
			}

			// Depth
			popoverRow(
				"Depth",
				value: units.depthForDisplay(sample.depthMeters),
				decimals: 1,
				unit: units.depthLabel,
				color: Color.blue
			)

			// Temperature
			if let temp = sample.waterTempCelsius {
				popoverRow(
					"Temperature",
					value: units.tempForDisplay(temp),
					decimals: 1,
					unit: units.tempLabel,
					color: Self.temperatureColor
				)
			}

			// Tank pressure
			if let pressure = sample.tankPressureBar {
				popoverRow(
					"Tank Pressure",
					value: units.pressureForDisplay(pressure),
					decimals: 0,
					unit: units.pressureLabel,
					color: Self.tankPressureColor
				)
			}

			// PPO₂
			if let ppo2 = sample.ppo2Bar {
				popoverRow(
					"PPO\u{2082}",
					value: ppo2,
					decimals: 2,
					unit: "ata",
					color: Self.ppo2Color
				)
			}

			// CNS
			if let cns = sample.cnsPercent {
				popoverRow(
					"CNS",
					value: cns,
					decimals: 0,
					unit: "%",
					color: Self.cnsColor
				)
			}

			// Deco status
			if let status = sample.decoStatus {
				GridRow {
					Circle()
						.fill(Self.decoTypeColor(for: status))
						.frame(width: 6, height: 6)
						.brightness(indicatorBrightness)
					Text("Deco Status")
						.font(.caption2)
						.foregroundStyle(.secondary)
					Text(status.displayName)
						.font(.caption2)
						.padding(.leading, 2)
						.gridColumnAlignment(.trailing)
				}
			}

			// Deco time
			if let decoTime = sample.decoTimeSeconds {
				popoverRow(
					"Time to Deco",
					value: Double(decoTime) / 60.0,
					decimals: 0,
					unit: "min",
					color: Self.decoTimeColor
				)
			}

			// Deco depth
			if let decoDepth = sample.decoDepthMeters {
				popoverRow(
					"Deco Depth",
					value: units.depthForDisplay(decoDepth),
					decimals: 1,
					unit: units.depthLabel,
					color: Self.decoDepthColor
				)
			}

			// RBT
			if let rbt = sample.rbtSeconds {
				popoverRow(
					"RBT",
					value: Double(rbt) / 60.0,
					decimals: 0,
					unit: "min",
					color: Self.rbtColor
				)
			}

			// Heart rate
			if let hr = sample.heartbeatBPM {
				GridRow {
					Image(systemName: "heart.fill")
						.font(.system(size: 6))
						.foregroundStyle(.red)
					Text("HR")
						.font(.caption2)
						.foregroundStyle(.secondary)
					Text("\(hr) bpm")
						.font(.caption2)
						.padding(.leading, 2)
						.gridColumnAlignment(.trailing)
				}
			}

			// Bearing
			if let bearing = sample.bearingDegrees {
				GridRow {
					Image(systemName: "location.north.fill")
						.font(.system(size: 6))
						.foregroundStyle(.secondary)
					Text("Bearing")
						.font(.caption2)
						.foregroundStyle(.secondary)
					Text("\(bearing)°")
						.font(.caption2)
						.padding(.leading, 2)
						.gridColumnAlignment(.trailing)
				}
			}
		}
		.padding(8)
		.foregroundStyle(.white)
		.background(Color.black.opacity(0.7), in: .rect(cornerRadius: 8))
		.glassEffect(.regular, in: .rect(cornerRadius: 8))
	}

	private func popoverRow(
		_ label: String,
		value: Double,
		decimals: Int,
		unit: String,
		color: Color
	) -> some View {
		GridRow {
			Circle()
				.fill(color)
				.frame(width: 6, height: 6)
				.brightness(indicatorBrightness)
			Text(label)
				.font(.caption2)
				.foregroundStyle(.secondary)
			Text("\(value, format: .number.precision(.fractionLength(decimals))) \(unit)")
				.font(.caption2)
				.padding(.leading, 2)
				.gridColumnAlignment(.trailing)
		}
	}

	// MARK: - Colors

	private static let temperatureColor: Color = .orange
	private static let tankPressureColor: Color = .green
	private static let ppo2Color: Color = .purple
	private static let cnsColor: Color = .red
	private static let decoTypeToggleColor: Color = .cyan
	/// Indigo in light mode; a lighter indigo in dark mode, where system indigo falls below 3:1
	/// against the dark tile. Defined as an adaptive color set in the asset catalog.
	private static let decoTimeColor: Color = .decoTimeOverlay
	private static let decoDepthColor: Color = .pink
	private static let rbtColor: Color = .yellow

	private static func decoTypeColor(for status: DecoType) -> Color {
		switch status {
			case .noDecoLimit: .green
			case .safetyStop: .yellow
			case .decoStop: .red
			case .deepStop: .purple
		}
	}

	// MARK: - Dynamic Right Axis

	/// Information needed to render the right-side Y axis for a single active overlay.
	private struct OverlayAxisInfo {
		let range: OverlayRange
		let color: Color
		let suffix: String
		let decimals: Int
		var usesFullChart: Bool = false
	}

	/// Returns axis info only when exactly one overlay toggle is active (excluding
	/// deco status, which is categorical and has no meaningful numeric axis).
	private func soleActiveOverlayAxis(data: ChartData) -> OverlayAxisInfo? {
		var active: [OverlayAxisInfo] = []

		if showTemperature && data.hasTemperature {
			active.append(OverlayAxisInfo(range: data.tempRange, color: Self.temperatureColor, suffix: units.tempLabel, decimals: 1, usesFullChart: true))
		}
		if showTankPressure && data.hasTankPressure {
			active.append(OverlayAxisInfo(range: data.pressureRange, color: Self.tankPressureColor, suffix: " \(units.pressureLabel)", decimals: 0, usesFullChart: true))
		}
		if showPPO2 && data.hasPPO2 {
			active.append(OverlayAxisInfo(range: data.ppo2Range, color: Self.ppo2Color, suffix: " bar", decimals: 2, usesFullChart: true))
		}
		if showCNS && data.hasCNS {
			active.append(OverlayAxisInfo(range: data.cnsRange, color: Self.cnsColor, suffix: "%", decimals: 0))
		}
		if showDecoTime && data.hasDecoTime {
			active.append(OverlayAxisInfo(range: data.decoTimeRange, color: Self.decoTimeColor, suffix: " min", decimals: 0, usesFullChart: true))
		}
		if showDecoDepth && data.hasDecoDepth {
			active.append(OverlayAxisInfo(range: data.decoDepthRange, color: Self.decoDepthColor, suffix: " \(units.depthLabel)", decimals: 0))
		}
		if showRBT && data.hasRBT {
			active.append(OverlayAxisInfo(range: data.rbtRange, color: Self.rbtColor, suffix: " min", decimals: 0))
		}

		// Deco status counts toward the total but can't provide an axis
		let decoTypeActive = showDecoType && data.hasDecoType
		let totalActive = active.count + (decoTypeActive ? 1 : 0)

		guard totalActive == 1, let sole = active.first else { return nil }
		return sole
	}

	/// Generates evenly spaced axis tick values for a given overlay range.
	private func overlayAxisValues(data: ChartData, axisInfo: OverlayAxisInfo) -> [Double] {
		let range = axisInfo.range
		let span = range.max - range.min
		guard span > 0 else { return [] }

		// "Nice number" step selection aiming for ~4 ticks
		let rawStep = span / 4.0
		let magnitude = pow(10, (log10(rawStep)).rounded(.down))
		let normalized = rawStep / magnitude
		let niceStep: Double
		if normalized <= 1 { niceStep = magnitude } else if normalized <= 2 { niceStep = 2 * magnitude } else if normalized <= 5 { niceStep = 5 * magnitude } else { niceStep = 10 * magnitude }

		let start = (range.min / niceStep).rounded(.up) * niceStep
		var values: [Double] = []
		var v = start
		while v <= range.max {
			let scaled = axisInfo.usesFullChart
			? data.scaleToFullChart(v, range: range)
			: data.scaleToOverlayBand(v, range: range)
			values.append(scaled)
			v += niceStep
		}
		return values
	}

	// MARK: - Private Types

	private struct OverlayRange {
		let min: Double
		let max: Double
	}

	private struct ChartData {
		let sortedSamples: [DepthSample]
		let maxDisplayDepth: Double
		let maxTime: Double

		// Data availability flags
		let hasTemperature: Bool
		let hasTankPressure: Bool
		let hasPPO2: Bool
		let hasCNS: Bool
		let hasDecoType: Bool
		let hasDecoTime: Bool
		let hasDecoDepth: Bool
		let hasRBT: Bool

		// Value ranges for each overlay (in display units)
		let tempRange: OverlayRange
		let pressureRange: OverlayRange
		let ppo2Range: OverlayRange
		let cnsRange: OverlayRange
		let decoTimeRange: OverlayRange
		let decoDepthRange: OverlayRange
		let rbtRange: OverlayRange

		/// Bottom of the overlay band in chart Y coordinates.
		var overlayBandBottom: Double { -maxDisplayDepth * 0.35 }

		/// Scales a display-unit value into the overlay band (overlayBandBottom...0).
		func scaleToOverlayBand(_ value: Double, range: OverlayRange) -> Double {
			guard range.max > range.min else { return overlayBandBottom }
			let fraction = (value - range.min) / (range.max - range.min)
			return overlayBandBottom + fraction * (0.0 - overlayBandBottom)
		}

		/// Reverse-scales a chart Y coordinate back to a display-unit value.
		func unscaleFromOverlayBand(_ y: Double, range: OverlayRange) -> Double {
			let fraction = (y - overlayBandBottom) / (0.0 - overlayBandBottom)
			return range.min + fraction * (range.max - range.min)
		}

		/// Scales a display-unit value into the full chart height (-maxDisplayDepth...0).
		func scaleToFullChart(_ value: Double, range: OverlayRange) -> Double {
			guard range.max > range.min else { return -maxDisplayDepth }
			let fraction = (value - range.min) / (range.max - range.min)
			return -maxDisplayDepth + fraction * maxDisplayDepth
		}

		/// Reverse-scales a full-chart Y coordinate back to a display-unit value.
		func unscaleFromFullChart(_ y: Double, range: OverlayRange) -> Double {
			let fraction = (y + maxDisplayDepth) / maxDisplayDepth
			return range.min + fraction * (range.max - range.min)
		}
	}
}

// MARK: - Overlay Toggle Button

private struct OverlayToggleButton: View {
	let title: String
	let color: Color
	@Binding var isOn: Bool

	var body: some View {
		Button {
			isOn.toggle()
		} label: {
			HStack(spacing: 4) {
				Circle()
					.fill(isOn ? color : color.opacity(0.3))
					.frame(width: 8, height: 8)
				Text(title)
					.font(.caption)
			}
			.padding(.horizontal, 8)
			.padding(.vertical, 4)
			.background(isOn ? color.opacity(0.15) : Color.secondary.opacity(0.1))
			.clipShape(.capsule)
		}
		.buttonStyle(.plain)
	}
}

// MARK: - Preview

#Preview {
	let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
	// swiftlint:disable force_try
	let container = try! ModelContainer(
		for: Dive.self, GasMix.self, DiveSite.self, DepthSample.self,
		configurations: config
	)
	PreviewContainer.insertSampleData(into: container)
	let descriptor = FetchDescriptor<Dive>(sortBy: [SortDescriptor(\Dive.diveNumber, order: .reverse)])
	let dives: [Dive] = try! container.mainContext.fetch(descriptor)
	// swiftlint:enable force_try
	return ScrollView {
		// Mirrors DiveDetailView: the chart sits on a tile over the app gradient.
		DepthProfileChart(samples: dives.first!.diveProfile ?? [])
			.padding()
			.tileBackground()
			.padding()
	}
	.appGradientScrollBackground()
	.modelContainer(container)
}
