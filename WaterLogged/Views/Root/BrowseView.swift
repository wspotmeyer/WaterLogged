//
//  BrowseView.swift
//  WaterLogged
//
//  Created by John Meyer on 7/2/26.
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

/// The compact-width "Browse" tab of `AdaptiveRootView`: lists the
/// destinations whose tabs don't fit the iPhone tab bar. Selecting a row
/// asks the root view to reveal and select that tab (`AdaptiveRootView.open`).
struct BrowseView: View {
	let openTab: (RootTab) -> Void

	var body: some View {
		NavigationStack {
			List {
				Group {
					Section("Log Book") {
						// Trips normally has its own tab, but it gives up
						// its tab-bar slot while a Browse destination is revealed.
						BrowseRow(title: "Trips", systemImage: "airplane.path.dotted", tab: .trips, openTab: openTab)
					}
					Section("Gear") {
						BrowseRow(title: "Equipment", systemImage: "briefcase", tab: .equipment, openTab: openTab)
						BrowseRow(title: "Gases", systemImage: "aqi.medium", tab: .gasMixes, openTab: openTab)
					}
					Section("People") {
						BrowseRow(title: "Buddies", systemImage: "person.2", tab: .buddies, openTab: openTab)
						BrowseRow(title: "Owner", systemImage: "person.text.rectangle", tab: .owner, openTab: openTab)
					}
					Section("More") {
						BrowseRow(title: "Dive Stats", systemImage: "chart.bar.xaxis", tab: .stats, openTab: openTab)
						BrowseRow(title: "Tools", systemImage: "wrench.and.screwdriver", tab: .tools, openTab: openTab)
						BrowseRow(title: "Settings", systemImage: "gearshape", tab: .settings, openTab: openTab)
						BrowseRow(title: "About", systemImage: "info.circle", tab: .about, openTab: openTab)
					}
				}
				.alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
				.tileListRowBackground()
			}
			.navigationTitle("Browse")
			.appGradientScrollBackground()
		}
	}
}

/// A single Browse destination row that switches the root tab selection.
private struct BrowseRow: View {
	let title: String
	let systemImage: String
	let tab: RootTab
	let openTab: (RootTab) -> Void

	var body: some View {
		Button {
			openTab(tab)
		} label: {
			Label(title, systemImage: systemImage)
		}
	}
}

#Preview {
	BrowseView(openTab: { _ in })
}
