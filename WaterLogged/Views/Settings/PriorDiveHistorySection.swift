//
//  PriorDiveHistorySection.swift
//  WaterLogged
//
//  Created by John Meyer on 9/25/26.
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

/// Settings section for the dives and bottom time logged before the first entry in WaterLogged.
/// See `PriorDiveHistory`.
struct PriorDiveHistorySection: View {
	@AppStorage(PriorDiveHistory.diveCountKey) private var priorDiveCount = 0
	@AppStorage(PriorDiveHistory.bottomTimeMinutesKey) private var priorBottomTimeMinutes = 0

	/// Bridges the two stored values to `PriorDiveHistory`, which owns the clamping and the
	/// hours/minutes split.
	private var history: Binding<PriorDiveHistory> {
		Binding {
			PriorDiveHistory(diveCount: priorDiveCount, bottomTimeMinutes: priorBottomTimeMinutes)
		} set: { newValue in
			priorDiveCount = max(newValue.diveCount, 0)
			priorBottomTimeMinutes = max(newValue.bottomTimeMinutes, 0)
		}
	}

	var body: some View {
		Section {
			// Same layouts as DiveEntryView: a visible leading label on every platform, with the
			// fields' own titles hidden or empty so macOS doesn't repeat them beside each field.
			LabeledContent("Dives") {
				TextField("Dives", value: history.diveCount, format: .number)
					.labelsHidden()
#if !os(macOS)
					.keyboardType(.numberPad)
#endif
					.multilineTextAlignment(.trailing)
			}
			HStack {
				Text("Bottom Time")
				Spacer()
				TextField("", value: history.bottomTimeHoursComponent, format: .number.precision(.fractionLength(0)))
#if !os(macOS)
					.keyboardType(.numberPad)
#endif
					.multilineTextAlignment(.trailing)
					.frame(width: 50)
				Text("hrs")
				TextField("", value: history.bottomTimeMinutesComponent, format: .number.precision(.fractionLength(0)))
#if !os(macOS)
					.keyboardType(.numberPad)
#endif
					.multilineTextAlignment(.trailing)
					.frame(width: 50)
				Text("min")
			}
		} header: {
			Text("Prior Dive History")
		} footer: {
			Text("Dives and bottom time from before your first logged dive. These are added to the totals shown in Statistics, on the Home map, and in widgets.")
		}
		// Keep the home-screen widget's totals in step with the new values.
		.onChange(of: priorDiveCount) {
			StatsWidgetCoordinator.shared.refreshNow()
		}
		.onChange(of: priorBottomTimeMinutes) {
			StatsWidgetCoordinator.shared.refreshNow()
		}
	}
}

#Preview {
	Form {
		PriorDiveHistorySection()
	}
	.formStyle(.grouped)
}
