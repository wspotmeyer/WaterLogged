//
//  SamplesToolView.swift
//  WaterLogged
//
//  Created by John Meyer on 4/24/26.
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

struct SamplesToolView: View {
	@Environment(\.modelContext) private var modelContext
	@AppStorage("unitSystem") private var unitSystem: UnitSystem = .imperial

	@Query(sort: \Dive.date, order: .reverse) private var dives: [Dive]

	@State private var selectedDive: Dive?
	@State private var xmlText = ""
	@State private var showConfirmation = false
	@State private var showResult = false
	@State private var resultMessage = ""
	@State private var resultIsError = false

	var body: some View {
		NavigationStack {
			Form {
				Group {
					Section {
						Picker("Dive", selection: $selectedDive) {
							Text("Select a dive…").tag(Dive?.none)
							ForEach(dives) { dive in
								Text(diveLabel(dive)).tag(Dive?.some(dive))
							}
						}
					} header: {
						Text("Target Dive")
					} footer: {
						Text("The selected dive's depth profile will be replaced with the imported samples.")
					}

					Section("MacDive Sample XML") {
						TextEditor(text: $xmlText)
							.font(.system(.body, design: .monospaced))
							.frame(minHeight: 200)
							.autocorrectionDisabled()
#if !os(macOS)
							.textInputAutocapitalization(.never)
#endif
					}

					Section {
						HStack {
							Text("Unit system")
							Spacer()
							Text(unitSystem.displayName)
								.foregroundStyle(.secondary)
						}
					} footer: {
						Text("Pasted values will be interpreted as \(unitSystem.displayName.lowercased()) units. Change this in Settings if needed.")
					}

					Section {
						Button("Import Samples", action: validateAndConfirm)
							.disabled(selectedDive == nil || xmlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
					}
				}
				.tileListRowBackground()
			}
			.formStyle(.grouped)
			.appGradientScrollBackground()
			.frame(maxWidth: 700)
			.frame(maxWidth: .infinity)
			.navigationTitle("Import Samples")
#if !os(macOS)
			.navigationBarTitleDisplayMode(.inline)
#endif
			.confirmationDialog(
				"Replace Depth Profile?",
				isPresented: $showConfirmation,
				titleVisibility: .visible
			) {
				Button("Replace", role: .destructive, action: performImport)
				Button("Cancel", role: .cancel) {}
			} message: {
				if let dive = selectedDive {
					let existingCount = dive.diveProfile?.count ?? 0
					Text("This will delete \(existingCount) existing depth sample\(existingCount == 1 ? "" : "s") from \"\(dive.displayTitle)\" and replace them with the pasted data.")
				}
			}
			.alert(resultIsError ? "Import Failed" : "Import Successful", isPresented: $showResult) {
				Button("OK") {
					if !resultIsError {
						xmlText = ""
						selectedDive = nil
					}
				}
			} message: {
				Text(resultMessage)
			}
		}
	}

	private func diveLabel(_ dive: Dive) -> String {
		let dateString = dive.date.formatted(date: .abbreviated, time: .omitted)
		if dive.diveNumber > 0 {
			return "#\(dive.diveNumber) — \(dive.displayTitle) (\(dateString))"
		}
		return "\(dive.displayTitle) (\(dateString))"
	}

	private func validateAndConfirm() {
		showConfirmation = true
	}

	private func performImport() {
		guard let dive = selectedDive else { return }

		do {
			try MacDiveSampleImporter.importSamples(
				from: xmlText,
				into: dive,
				unitSystem: unitSystem,
				context: modelContext
			)
			let count = dive.diveProfile?.count ?? 0
			resultMessage = "Imported \(count) depth sample\(count == 1 ? "" : "s") into \"\(dive.displayTitle)\"."
			resultIsError = false
		} catch {
			resultMessage = error.localizedDescription
			resultIsError = true
		}

		showResult = true
	}
}

#Preview {
	SamplesToolView()
}
