//
//  DiveImportConfirmationView.swift
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

struct DiveImportConfirmationView: View {
	let dives: [ParsedDiveData]
	/// How much was pulled off the device, shown so an incremental download can
	/// be compared against a full one.
	let transferSummary: String?
	let onImport: ([ParsedDiveData]) -> Void

	@State private var selectedIndices: Set<Int> = []

	private var allSelected: Bool {
		selectedIndices.count == dives.count
	}

	var body: some View {
		VStack {
			HStack {
				Image(systemName: "checkmark.circle")
					.font(.title2)
					.foregroundStyle(.green)
				Text("\(dives.count) Dive\(dives.count == 1 ? "" : "s") Ready to Import")
					.font(.title3)
					.bold()
			}
			.padding(.top)

			if let model = dives.first?.computerModel {
				Text("From: \(model)")
					.font(.subheadline)
					.foregroundStyle(.secondary)
			}

			if let transferSummary {
				Text(transferSummary)
					.font(.caption)
					.foregroundStyle(.secondary)
			}

			List(selection: $selectedIndices) {
				ForEach(dives.indices, id: \.self) { index in
					DiveTransferRowView(dive: dives[index])
				}
				.tileListRowBackground()
			}
			.scrollContentBackground(.hidden)
			.frame(maxHeight: .infinity)
#if os(iOS)
			.environment(\.editMode, .constant(.active))
#endif

			HStack {
				Button(allSelected ? "Deselect All" : "Select All") {
					if allSelected {
						selectedIndices = []
					} else {
						selectedIndices = Set(dives.indices)
					}
				}

				Spacer()

				Button("Import \(selectedIndices.count) Dive\(selectedIndices.count == 1 ? "" : "s")") {
					let selected = selectedIndices.sorted().map { dives[$0] }
					onImport(selected)
				}
				.buttonStyle(.borderedProminent)
				.disabled(selectedIndices.isEmpty)
			}
			.padding()
		}
		.frame(minHeight: 500)
		.onAppear {
			selectedIndices = Set(dives.indices)
		}
	}
}
