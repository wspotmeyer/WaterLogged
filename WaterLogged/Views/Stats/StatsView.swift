//
//  StatsView.swift
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

struct StatsView: View {
	@Query(sort: \Dive.date, order: .reverse) var dives: [Dive]
	@Query var trips: [Trip]
	@AppStorage("unitSystem") private var unitSystem: UnitSystem = .imperial
	@AppStorage(PriorDiveHistory.diveCountKey) private var priorDiveCount = 0
	@AppStorage(PriorDiveHistory.bottomTimeMinutesKey) private var priorBottomTimeMinutes = 0
	@Environment(\.colorScheme) private var colorScheme
	// Owned here rather than by each chart so that switching between the one- and
	// two-column layouts doesn't reset the pickers.
	@State private var countryMetric: StatMetric = .dives
	@State private var regionMetric: StatMetric = .dives
	@State private var buddyMetric: StatMetric = .dives
	@State private var tagMetric: StatMetric = .dives
	@State private var waterAndGasMetric: StatMetric = .dives

	private var units: UnitFormatter { UnitFormatter(system: unitSystem) }

	/// Dives and bottom time from before the logbook began, added to the summary totals only —
	/// they can't be attributed to a year, country, buddy, or tag, so the charts leave them out.
	private var priorHistory: PriorDiveHistory {
		PriorDiveHistory(diveCount: priorDiveCount, bottomTimeMinutes: priorBottomTimeMinutes)
	}

	private var totalDives: Int { priorHistory.totalDives(logged: dives.count) }

	/// Most bar rows a chart reserves before it starts scrolling. Fewer in the single-column
	/// layout, where a section has to fit a phone screen rather than half a window.
	private static let maxSideBySideBars = 10
	private static let maxSingleColumnBars = 8

	/// Rows each bar chart reserves, so all four sections come out the same height. Sized to the
	/// fullest chart so none is padded out with dead space, and capped so a long tail scrolls
	/// rather than stretching the page — uncapped, the tag or buddy chart runs taller than the
	/// screen and there is nothing left to scroll. Counted from the unfiltered groupings, which
	/// also keeps a section's height steady as its metric picker filters rows out.
	private func sharedBarCapacity(cap: Int) -> Int {
		let groupCounts = [
			countriesVisited,
			Set(dives.compactMap { $0.site?.region }.filter { !$0.isEmpty }).count,
			Set(dives.flatMap { $0.buddies ?? [] }.map(\.externalId)).count,
			Set(dives.flatMap(\.tags).filter { !$0.isEmpty }).count
		]
		return min(max(groupCounts.max() ?? 1, 1), cap)
	}

	var body: some View {
		NavigationStack {
			Group {
				if dives.isEmpty {
					ContentUnavailableView(
						"No Statistics Yet",
						systemImage: "chart.bar",
						description: Text("Log your first dive to see statistics.")
					)
				} else {
					ScrollView {
						VStack(alignment: .leading, spacing: 24) {
							summaryGrid
							Divider()
							divesPerYearAndWaterGasSections
							countryAndRegionSections
							buddyAndTagSections
						}
						.padding()
					}
				}
			}
			.appGradientScrollBackground()
			.navigationTitle("Statistics")
		}
	}

	// MARK: - Summary Grid

	private var summaryGrid: some View {
		ViewThatFits(in: .horizontal) {
			HStack(spacing: 16) {
				StatCell(label: "Total Dives", value: "\(totalDives)", icon: "number")
				StatCell(label: "Bottom Time", value: totalBottomTime, icon: "clock.fill")
				StatCell(label: "Max Depth", value: maxDepthText, icon: "arrow.down.to.line")
				StatCell(label: "Countries", value: "\(countriesVisited)", icon: "globe")
				StatCell(label: "Dive Sites", value: "\(diveSitesVisited)", icon: "mappin.and.ellipse")
				StatCell(label: "Trips", value: "\(trips.count)", icon: "airplane.path.dotted")
			}
			VStack(spacing: 16) {
				HStack(spacing: 16) {
					StatCell(label: "Total Dives", value: "\(totalDives)", icon: "number")
					StatCell(label: "Bottom Time", value: totalBottomTime, icon: "clock.fill")
					StatCell(label: "Max Depth", value: maxDepthText, icon: "arrow.down.to.line")
				}
				HStack(spacing: 16) {
					StatCell(label: "Countries", value: "\(countriesVisited)", icon: "globe")
					StatCell(label: "Dive Sites", value: "\(diveSitesVisited)", icon: "mappin.and.ellipse")
					StatCell(label: "Trips", value: "\(trips.count)", icon: "airplane.path.dotted")
				}
			}
		}
	}

	private var totalBottomTime: String {
		let total = priorHistory.totalBottomTimeSeconds(logged: StatsSnapshotBuilder.loggedBottomTimeSeconds(of: dives))
		let hours = total / 3600
		let minutes = (total % 3600) / 60
		if hours > 0 {
			return "\(hours)h \(minutes)m"
		}
		return "\(minutes)m"
	}

	private var countriesVisited: Int {
		StatsSnapshotBuilder.countriesVisited(in: dives)
	}

	private var diveSitesVisited: Int {
		StatsSnapshotBuilder.diveSitesVisited(in: dives)
	}

	private var maxDepthText: String {
		guard let max = StatsSnapshotBuilder.deepestDepthMeters(of: dives) else { return "—" }
		return units.depthString(max)
	}

	// MARK: - Dives Per Year and Water & Gas Charts

	private var divesPerYearAndWaterGasSections: some View {
		ViewThatFits(in: .horizontal) {
			HStack(alignment: .top, spacing: 16) {
				divesPerYearSection
					.frame(minWidth: 350, maxHeight: .infinity)
				waterAndGasSection
					.frame(minWidth: 350, maxHeight: .infinity)
			}
			// Sizes the row to the taller section, which the other then stretches to fill.
			.fixedSize(horizontal: false, vertical: true)
			VStack(spacing: 16) {
				divesPerYearSection
				waterAndGasSection
			}
		}
	}

	private var divesPerYearSection: some View {
		DetailSection(title: "Dives Per Year") {
			Chart(divesPerYear) { item in
				BarMark(
					x: .value("Year", item.year, unit: .year),
					y: .value("Dives", item.count)
				)
				// Same color as the Dives metric in the bar sections below, so the page doesn't
				// show two near-identical blues.
				.foregroundStyle(StatMetric.dives.color(for: colorScheme))
				.clipShape(.rect(cornerRadius: 4))
				.annotation(position: .top) {
					Text("\(item.count)")
						.font(.caption2)
						.foregroundStyle(.secondary)
				}
			}
			.chartXAxis {
				AxisMarks(values: .stride(by: .year)) { _ in
					AxisGridLine()
					AxisValueLabel(format: .dateTime.year(), centered: true, collisionResolution: .greedy, orientation: .verticalReversed)
						.font(.caption2.monospacedDigit())
				}
			}
			.chartYAxis {
				AxisMarks { _ in
					AxisGridLine()
					AxisValueLabel()
				}
			}
			// Grows past its minimum when paired with the water and gas section, so the two
			// sections sitting side by side come out the same height.
			.frame(minHeight: 220, idealHeight: 220, maxHeight: .infinity)
		}
	}

	private var divesPerYear: [YearlyDiveCount] {
		let calendar = Calendar.current
		let grouped = Dictionary(grouping: dives) { dive in
			calendar.dateInterval(of: .year, for: dive.date)!.start
		}
		return grouped
			.map { YearlyDiveCount(year: $0.key, count: $0.value.count) }
			.sorted { $0.year < $1.year }
	}

	private var waterAndGasSection: some View {
		MetricDonutChartSection(
			waterTypeSlices: waterTypeSlices,
			gasMixSlices: gasMixSlices,
			metric: $waterAndGasMetric
		)
	}

	/// One slice per water type, each on a fixed palette slot so a water type keeps its color
	/// whichever types are present. Listed in ring order; dives with no water type are left out.
	private var waterTypeSlices: [MetricDonutSlice] {
		let ringOrder: [(type: WaterType, paletteSlot: Int)] = [(.salt, 0), (.brackish, 1), (.fresh, 2)]
		var divesByType: [WaterType: [Dive]] = [:]
		for dive in dives {
			if let waterType = dive.waterType {
				divesByType[waterType, default: []].append(dive)
			}
		}
		return ringOrder.compactMap { entry in
			guard let typeDives = divesByType[entry.type] else { return nil }
			return MetricDonutSlice(
				id: entry.type.rawValue,
				label: entry.type.rawValue,
				dives: typeDives,
				paletteSlot: entry.paletteSlot
			)
		}
	}

	/// One slice per gas mix breathed, grouped by display name so separately stored mixes with
	/// the same name share a slice. A dive counts once per mix however many tanks carried it,
	/// but once for *each* mix it used, so the slices can add up to more than the dives logged.
	private var gasMixSlices: [MetricDonutSlice] {
		var divesByGasMix: [String: [Dive]] = [:]
		for dive in dives {
			let names = Set((dive.tanks ?? []).compactMap { $0.gasMix?.displayName }.filter { !$0.isEmpty })
			for name in names {
				divesByGasMix[name, default: []].append(dive)
			}
		}
		return MetricDonutSlice.ranked(divesByGasMix)
	}

	// MARK: - Country and Region Charts

	private var countryAndRegionSections: some View {
		ViewThatFits(in: .horizontal) {
			HStack(alignment: .top, spacing: 16) {
				divesByCountryBarChart(barCapacity: sharedBarCapacity(cap: Self.maxSideBySideBars))
					.frame(minWidth: 350)
				divesByRegionBarChart(barCapacity: sharedBarCapacity(cap: Self.maxSideBySideBars))
					.frame(minWidth: 350)
			}
			VStack(spacing: 16) {
				divesByCountryBarChart(barCapacity: sharedBarCapacity(cap: Self.maxSingleColumnBars))
				divesByRegionBarChart(barCapacity: sharedBarCapacity(cap: Self.maxSingleColumnBars))
			}
		}
	}

	private func divesByCountryBarChart(barCapacity: Int?) -> some View {
		MetricBarChartSection(category: "Country", values: countryStatValues, metric: $countryMetric, barCapacity: barCapacity)
	}

	private func divesByRegionBarChart(barCapacity: Int?) -> some View {
		MetricBarChartSection(category: "Region", values: regionStatValues, metric: $regionMetric, barCapacity: barCapacity)
	}

	private var countryStatValues: [StatMetricValue] {
		let grouped = Dictionary(grouping: dives.filter { !($0.site?.country.isEmpty ?? true) }) { dive in
			dive.site?.country ?? ""
		}
		return grouped.map { country, countryDives in
			let flag = CountryFlag.emoji(for: country)
			let label = if let flag { "\(flag) \(country)" } else { country }
			return StatMetricValue(
				id: country,
				label: label,
				sortName: country,
				diveCount: countryDives.count,
				bottomTimeSeconds: countryDives.reduce(0) { $0 + $1.durationSeconds },
				tripCount: Self.tripCount(of: countryDives)
			)
		}
	}

	private var regionStatValues: [StatMetricValue] {
		let grouped = Dictionary(grouping: dives.filter { !($0.site?.region.isEmpty ?? true) }) { dive in
			dive.site?.region ?? ""
		}
		return grouped.map { region, regionDives in
			StatMetricValue(
				id: region,
				label: region,
				sortName: region,
				diveCount: regionDives.count,
				bottomTimeSeconds: regionDives.reduce(0) { $0 + $1.durationSeconds },
				tripCount: Self.tripCount(of: regionDives)
			)
		}
	}

	/// Number of distinct trips a group of dives belongs to. Dives with no trip are ignored,
	/// so a group can legitimately report zero trips.
	private static func tripCount(of dives: [Dive]) -> Int {
		Set(dives.compactMap { $0.trip?.externalId }).count
	}

	// MARK: - Buddy and Tag Charts

	private var buddyAndTagSections: some View {
		ViewThatFits(in: .horizontal) {
			HStack(alignment: .top, spacing: 16) {
				divesByBuddyBarChart(barCapacity: sharedBarCapacity(cap: Self.maxSideBySideBars))
					.frame(minWidth: 350)
				divesByTagBarChart(barCapacity: sharedBarCapacity(cap: Self.maxSideBySideBars))
					.frame(minWidth: 350)
			}
			VStack(spacing: 16) {
				divesByBuddyBarChart(barCapacity: sharedBarCapacity(cap: Self.maxSingleColumnBars))
				divesByTagBarChart(barCapacity: sharedBarCapacity(cap: Self.maxSingleColumnBars))
			}
		}
	}

	private func divesByBuddyBarChart(barCapacity: Int?) -> some View {
		MetricBarChartSection(category: "Buddy", values: buddyStatValues, metric: $buddyMetric, barCapacity: barCapacity)
	}

	private var buddyStatValues: [StatMetricValue] {
		// Dives are collected per buddy rather than accumulated, so trips can be counted
		// distinctly alongside the dive and bottom-time totals.
		var totals: [String: (name: String, dives: [Dive])] = [:]
		for dive in dives {
			guard let buddies = dive.buddies else { continue }
			for buddy in buddies {
				let existing = totals[buddy.externalId]
				totals[buddy.externalId] = (
					existing?.name ?? buddy.formattedName,
					(existing?.dives ?? []) + [dive]
				)
			}
		}
		return totals.map { externalId, totals in
			StatMetricValue(
				id: externalId,
				label: totals.name,
				sortName: totals.name,
				diveCount: totals.dives.count,
				bottomTimeSeconds: totals.dives.reduce(0) { $0 + $1.durationSeconds },
				tripCount: Self.tripCount(of: totals.dives)
			)
		}
	}

	private func divesByTagBarChart(barCapacity: Int?) -> some View {
		MetricBarChartSection(category: "Tag", values: tagStatValues, metric: $tagMetric, barCapacity: barCapacity)
	}

	private var tagStatValues: [StatMetricValue] {
		var divesByTag: [String: [Dive]] = [:]
		for dive in dives {
			for tag in dive.tags where !tag.isEmpty {
				divesByTag[tag, default: []].append(dive)
			}
		}
		return divesByTag.map { tag, tagDives in
			StatMetricValue(
				id: tag,
				label: tag,
				sortName: tag,
				diveCount: tagDives.count,
				bottomTimeSeconds: tagDives.reduce(0) { $0 + $1.durationSeconds },
				tripCount: Self.tripCount(of: tagDives)
			)
		}
	}
}

private struct YearlyDiveCount: Identifiable {
	let year: Date
	let count: Int
	var id: Date { year }
}

#Preview {
	StatsView()
		.modelContainer(PreviewContainer.container)
}

// The chart sections only pair up when the page is wide; force that here so the
// two-column layout stays previewable on a small canvas.
#Preview("Wide Layout") {
	StatsView()
		.frame(minWidth: 1400, minHeight: 1000)
		.modelContainer(PreviewContainer.container)
}
