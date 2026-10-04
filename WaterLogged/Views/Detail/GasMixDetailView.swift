//
//  GasMixDetailView.swift
//  WaterLogged
//
//  Created by John Meyer on 2/24/26.
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

struct GasMixDetailView: View {
	@Environment(\.modelContext) private var modelContext
	@Environment(\.dismiss) private var dismiss

	let gasMix: GasMix
	@State private var editingGasMix: GasMix?
	@State private var isDivesExpanded = false

	/// Chart colors are a presentation concern, so they live here rather than on the model.
	private func color(for kind: GasComponent.Kind) -> Color {
		switch kind {
		case .oxygen: .blue
		case .nitrogen: .green
		case .helium: .purple
		case .argon: .orange
		case .hydrogen: .pink
		}
	}

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 24) {

				// Header
				VStack(alignment: .leading, spacing: 6) {
					if !gasMix.name.isEmpty {
						Text(gasMix.componentSummary)
							.font(.subheadline)
					}
				}

				Divider()

				// Pie Chart
				VStack(alignment: .leading, spacing: 10) {
					Chart(gasMix.components) { component in
						SectorMark(
							angle: .value(component.name, component.fraction),
							innerRadius: .ratio(0.5),
							angularInset: 1.5
						)
						.foregroundStyle(color(for: component.kind))
						.cornerRadius(2)
						.annotation(position: .overlay) {
							Text(component.fraction, format: .percent.precision(.fractionLength(0)))
								.font(.caption.bold())
								.foregroundStyle(.white)
						}
					}
					.chartLegend(position: .bottom)
					.chartBackground { chartProxy in
						GeometryReader { geometry in
							if let plotFrame = chartProxy.plotFrame {
								let frame = geometry[plotFrame]
								VStack {
									Text("Gas Mixture")
										.font(.callout)
									if !gasMix.name.isEmpty {
										Text(gasMix.name)
											.font(.title2.bold())
											.foregroundStyle(Color.primary)
									}
								}
								.position(x: frame.midX, y: frame.midY)
							}
						}
					}
					.frame(height: 220)

					// Legend labels
					HStack(spacing: 16) {
						ForEach(gasMix.components) { component in
							HStack(spacing: 4) {
								Circle()
									.fill(color(for: component.kind))
									.frame(width: 10, height: 10)
								Text(component.name)
									.font(.caption)
							}
						}
					}
					.frame(maxWidth: .infinity)
				}

				// Associated Dives
				let associatedDives = Array(Set((gasMix.tanks ?? []).compactMap(\.dive)))
				if !associatedDives.isEmpty {
					let dives = associatedDives
					Divider()

					GroupBox {
						if isDivesExpanded {
							VStack(spacing: 0) {
								ForEach(dives.sorted(by: { $0.date < $1.date })) { dive in
									DiveLinkRow(dive: dive)
								}
							}
						}
					} label: {
						HStack {
							Text("Dives")
								.font(.title2.bold())
							Spacer()
							TimeCount(seconds: gasMix.totalDiveTimeSeconds, font: .headline)
							DiveCount(count: dives.count, font: .headline)
							DisclosureToggleButton(isExpanded: $isDivesExpanded, subject: "Dives")
						}
					}
					.tileBackgroundStyle()
				}
			}
			.padding()
		}
		.appGradientScrollBackground()
		.navigationTitle(gasMix.displayName)
		.toolbar {
			ToolbarItem(placement: .primaryAction) {
				Button("Edit", systemImage: "pencil") {
					editingGasMix = gasMix
				}
			}
		}
		.sheet(item: $editingGasMix) { editing in
			GasMixEntryView(gasMix: editing, onDelete: {
				modelContext.delete(editing)
				dismiss()
			})
		}
	}
}

#Preview {
	let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
	// swiftlint:disable force_try
	let container = try! ModelContainer(
		for: Dive.self, GasMix.self, DiveSite.self, DepthSample.self,
		configurations: config
	)
	PreviewContainer.insertSampleData(into: container)
	let gasMix = try! container.mainContext.fetch(FetchDescriptor<GasMix>()).first!
	// swiftlint:enable force_try
	return NavigationStack {
		GasMixDetailView(gasMix: gasMix)
	}
	.modelContainer(container)
}
