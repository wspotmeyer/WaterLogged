//
//  DivesSection.swift
//  WaterLogged
//
//  Created by John Meyer on 10/6/26.
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

/// The collapsible "Dives" section on the buddy, certification, dive site, equipment,
/// gas mix and trip detail views: the given dives' total bottom time and count, and
/// each dive linking to its `DiveDetailView`.
struct DivesSection: View {
	let dives: [Dive]?

	@State private var isExpanded = false

	/// The combined bottom time of the dives, in seconds.
	static func totalDiveTimeSeconds(for dives: [Dive]) -> Int {
		dives.reduce(0) { $0 + $1.durationSeconds }
	}

	var body: some View {
		if let dives, !dives.isEmpty {
			GroupBox {
				if isExpanded {
					VStack(spacing: 0) {
						ForEach(dives.sorted(by: { $0.date < $1.date })) { dive in
							DiveLinkRow(dive: dive)
						}
					}
					.frame(maxWidth: .infinity, alignment: .leading)
				}
			} label: {
				HStack {
					Text("Dives")
						.font(.title2.bold())
					Spacer()
					TimeCount(seconds: Self.totalDiveTimeSeconds(for: dives), font: .headline)
					DiveCount(count: dives.count, font: .headline)
					DisclosureToggleButton(isExpanded: $isExpanded, subject: "Dives")
				}
			}
			.tileBackgroundStyle()
		}
	}
}
