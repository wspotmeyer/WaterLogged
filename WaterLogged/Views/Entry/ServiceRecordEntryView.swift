//
//  ServiceRecordEntryView.swift
//  WaterLogged
//
//  Created by John Meyer on 3/28/26.
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

struct ServiceRecordEntryView: View {
	@Environment(\.modelContext) private var modelContext
	@Environment(\.dismiss) private var dismiss

	let record: ServiceRecord?
	let equipment: Equipment

	@State private var serviceDate = Date.now
	@State private var servicedBy = ""
	@State private var notes = ""

	private var isEditing: Bool { record != nil }

	var body: some View {
		NavigationStack {
			Form {
				Group {
					Section("Service Details") {
						DatePicker("Service Date", selection: $serviceDate, displayedComponents: .date)
						LabeledContent("Servived By") {
							TextField("Serviced By", text: $servicedBy, prompt: Text("Servicer"))
								.labelsHidden()
								.multilineTextAlignment(.trailing)
						}
					}
					Section("Notes") {
						PlaceholderTextEditor(placeholder: "Notes", text: $notes)
					}
				}
				.tileListRowBackground()
			}
			.entryFormChrome(
				isEditing ? "Edit Service Record" : "New Service Record",
				onSave: {
					save()
					dismiss()
				},
				onCancel: { dismiss() }
			)
			.onAppear {
				if let record {
					serviceDate = record.serviceDate
					servicedBy = record.servicedBy
					notes = record.notes
				}
			}
		}
#if os(macOS)
		.frame(minWidth: 400, idealWidth: 480, minHeight: 300, idealHeight: 400)
#endif
	}

	private func save() {
		if let record {
			record.serviceDate = serviceDate
			record.servicedBy = servicedBy
			record.notes = notes
		} else {
			let newRecord = ServiceRecord(
				serviceDate: serviceDate,
				servicedBy: servicedBy,
				notes: notes
			)
			newRecord.equipment = equipment
			modelContext.insert(newRecord)
		}
	}
}

#Preview("New Service Record") {
	let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
	// swiftlint:disable:next force_try
	let container = try! ModelContainer(
		for: Equipment.self, ServiceRecord.self,
		configurations: config
	)
	let equipment = Equipment(name: "Test Regulator", manufacturer: "Aqua Lung")
	container.mainContext.insert(equipment)
	return ServiceRecordEntryView(record: nil, equipment: equipment)
		.modelContainer(container)
}
