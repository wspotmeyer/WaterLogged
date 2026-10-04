//
//  GasMixEntryView.swift
//  WaterLogged
//
//  Created by John Meyer on 3/27/26.
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

/// A form for creating or editing a gas mix.
struct GasMixEntryView: View {
	@Environment(\.modelContext) private var modelContext
	@Environment(\.dismiss) private var dismiss

	let gasMix: GasMix?
	var onSave: ((GasMix) -> Void)?
	var onDelete: (() -> Void)?

	@State private var name: String = "Air"
	@State private var oxygenPct: Double = 21
	@State private var heliumPct: Double = 0
	@State private var argonPct: Double = 0
	@State private var hydrogenPct: Double = 0

	private var isEditing: Bool { gasMix != nil }

	/// Nitrogen is the balance gas, so it follows whatever the diver enters for the others.
	private var nitrogenPct: Double {
		GasMix.nitrogenPercent(
			oxygen: oxygenPct,
			helium: heliumPct,
			argon: argonPct,
			hydrogen: hydrogenPct
		)
	}

	@State private var showingDeleteConfirmation = false

	var body: some View {
		NavigationStack {
			Form {
				Group {
					Section {
						TextField("Name (e.g. Air, EAN32)", text: $name)
						LabeledContent("O\u{2082} %") {
							TextField("Oxygen", value: $oxygenPct, format: .number, prompt: Text("21"))
								.labelsHidden()
#if !os(macOS)
								.keyboardType(.decimalPad)
#endif
								.multilineTextAlignment(.trailing)
						}
						LabeledContent("N\u{2082} %") {
							Text(nitrogenPct, format: .number.precision(.fractionLength(0...2)))
								.foregroundStyle(.secondary)
						}
						LabeledContent("He %") {
							TextField("Helium", value: $heliumPct, format: .number, prompt: Text("0"))
								.labelsHidden()
#if !os(macOS)
								.keyboardType(.decimalPad)
#endif
								.multilineTextAlignment(.trailing)
						}
						LabeledContent("Ar %") {
							TextField("Argon", value: $argonPct, format: .number, prompt: Text("0"))
								.labelsHidden()
#if !os(macOS)
								.keyboardType(.decimalPad)
#endif
								.multilineTextAlignment(.trailing)
						}
						LabeledContent("H\u{2082} %") {
							TextField("Hydrogen", value: $hydrogenPct, format: .number, prompt: Text("0"))
								.labelsHidden()
#if !os(macOS)
								.keyboardType(.decimalPad)
#endif
								.multilineTextAlignment(.trailing)
						}
					} header: {
						Text("Gas Composition")
					} footer: {
						Text("Nitrogen makes up the balance of the mix.")
					}
					if isEditing {
						DeleteItemSection(title: "Delete This Gas Mix", isConfirming: $showingDeleteConfirmation)
					}
				}
				.tileListRowBackground()
			}
			.entryFormChrome(
				isEditing ? "Edit Gas Mix" : "New Gas Mix",
				canSave: !name.isEmpty,
				onSave: {
					save()
					dismiss()
				},
				onCancel: { dismiss() }
			)
			.onAppear {
				if let gasMix {
					name = gasMix.name
					oxygenPct = gasMix.oxygenPercent
					heliumPct = gasMix.heliumPercent
					argonPct = gasMix.argonPercent
					hydrogenPct = gasMix.hydrogenPercent
				}
			}
			.deleteConfirmation(
				"Delete This Gas Mix?",
				isPresented: $showingDeleteConfirmation,
				message: "This will permanently delete this gas mix. Any dives using this mix will no longer have a gas mix assigned."
			) {
				dismiss()
				onDelete?()
			}
		}
#if os(macOS)
		.frame(minWidth: 400, idealWidth: 480, minHeight: 300, idealHeight: 400)
#endif
	}

	private func save() {
		if let gasMix {
			gasMix.name = name
			gasMix.oxygenPercent = oxygenPct
			gasMix.heliumPercent = heliumPct
			gasMix.argonPercent = argonPct
			gasMix.hydrogenPercent = hydrogenPct
			onSave?(gasMix)
		} else {
			let newMix = GasMix(
				name: name,
				oxygenPercent: oxygenPct,
				heliumPercent: heliumPct,
				argonPercent: argonPct,
				hydrogenPercent: hydrogenPct
			)
			modelContext.insert(newMix)
			onSave?(newMix)
		}
	}
}

#Preview("New Gas Mix") {
	GasMixEntryView(gasMix: nil)
		.modelContainer(PreviewContainer.container)
}
