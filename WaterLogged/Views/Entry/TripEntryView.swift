//
//  TripEntryView.swift
//  WaterLogged
//
//  Created by John Meyer on 4/20/26.
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

struct TripEntryView: View {
	@Environment(\.modelContext) private var modelContext
	@Environment(\.dismiss) private var dismiss

	let trip: Trip?
	var onDelete: (() -> Void)?

	@State private var name = ""
	@State private var startDate: Date = .now
	@State private var endDate: Date = .now
	@State private var location = ""
	@State private var address = ""
	@State private var latitudeString = ""
	@State private var longitudeString = ""
	@State private var urlString = ""
	@State private var notes = ""
	@State private var autoAddDives = false

	@State private var showingDeleteConfirmation = false

	private var isEditing: Bool { trip != nil }

	var body: some View {
		NavigationStack {
			Form {
				Group {
					Section("Trip") {
						TextField("Name", text: $name)
						TextField("Location", text: $location)
					}
					Section("Dates") {
						DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
						DatePicker("End Date", selection: $endDate, displayedComponents: .date)
					}
					Section {
						LabeledContent("Address") {
							TextField("Address", text: $address, prompt: Text("(optional)"))
								.labelsHidden()
								.multilineTextAlignment(.trailing)
						}
						LabeledContent("Latitude") {
							TextField("Latitude", text: $latitudeString, prompt: Text("(optional)"))
								.labelsHidden()
#if !os(macOS)
								.keyboardType(.numbersAndPunctuation)
#endif
								.multilineTextAlignment(.trailing)
						}
						LabeledContent("Longitude") {
							TextField("Longitude", text: $longitudeString, prompt: Text("(optional)"))
								.labelsHidden()
#if !os(macOS)
								.keyboardType(.numbersAndPunctuation)
#endif
								.multilineTextAlignment(.trailing)
						}
					} header: {
						Text("Residence")
					} footer: {
						Text("Use the Address field to supply a name or address of a resort, hotel, or boat. Optionally, use the Latitude and Longitude fields to specify an exact location and the Address text will be used to label the location.")
					}
					Section {
						TextField("Optional", text: $urlString)
#if !os(macOS)
							.keyboardType(.URL)
							.textInputAutocapitalization(.never)
#endif
					} header: {
						Text("Trip URL")
					} footer: {
						Text("A URL to the trip's detailed information (for example, a [TripIt](https://www.tripit.com) link).")
					}
					Section {
						ZStack(alignment: .topLeading) {
							if notes.isEmpty {
								Text("Notes")
									.foregroundStyle(.tertiary)
									.padding(.top, 8)
									.padding(.leading, 4)
							}
							TextEditor(text: $notes)
								.frame(minHeight: 100)
						}
					} header: {
						Text("Notes")
					} footer: {
						Text("You can use text formatting (bold, italics, links, etc.) using inline Markdown syntax.")
					}
					Section {
						Toggle("Add Dives by Date", isOn: $autoAddDives)
					} footer: {
						Text("Automatically add all dives that fall within the trip dates.")
					}
					if isEditing {
						Section {
							Button("Delete This Trip", role: .destructive) {
								showingDeleteConfirmation = true
							}
						}
					}
				}
				.tileListRowBackground()
			}
			.formStyle(.grouped)
			.appGradientScrollBackground()
			.navigationTitle(isEditing ? "Edit Trip" : "New Trip")
#if !os(macOS)
			.navigationBarTitleDisplayMode(.inline)
#endif
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel", systemImage: "xmark") { dismiss() }
				}
				ToolbarItem(placement: .confirmationAction) {
					Button("Save", systemImage: "checkmark") {
						save()
						dismiss()
					}
					.buttonStyle(.borderedProminent)
					.disabled(name.isEmpty)
				}
			}
			.onAppear {
				if let trip {
					name = trip.name
					startDate = trip.startDate
					endDate = trip.endDate
					location = trip.location
					address = trip.address
					if let lat = trip.latitude {
						latitudeString = String(lat)
					}
					if let lon = trip.longitude {
						longitudeString = String(lon)
					}
					urlString = trip.urlString
					notes = trip.notes
				}
			}
			.alert("Delete This Trip?", isPresented: $showingDeleteConfirmation) {
				Button("Delete", role: .destructive) {
					dismiss()
					onDelete?()
				}
				Button("Cancel", role: .cancel) { }
			} message: {
				Text("This will permanently delete this trip. Any dives on this trip will remain, but they will no longer have a trip assigned.")
			}
		}
#if os(macOS)
		.frame(minWidth: 400, idealWidth: 480, minHeight: 450, idealHeight: 550)
#endif
	}

	private func save() {
		let parsedLat = Double(latitudeString)
		let parsedLon = Double(longitudeString)

		let targetTrip: Trip
		if let trip {
			trip.name = name
			trip.startDate = startDate
			trip.endDate = endDate
			trip.location = location
			trip.address = address
			trip.latitude = parsedLat
			trip.longitude = parsedLon
			trip.urlString = urlString
			trip.notes = notes
			targetTrip = trip
		} else {
			let newTrip = Trip(
				name: name,
				startDate: startDate,
				endDate: endDate,
				location: location,
				address: address,
				latitude: parsedLat,
				longitude: parsedLon,
				urlString: urlString,
				notes: notes
			)
			modelContext.insert(newTrip)
			targetTrip = newTrip
		}

		if autoAddDives {
			addDivesInRange(to: targetTrip)
		}
	}

	private func addDivesInRange(to trip: Trip) {
		let rangeStart = Calendar.current.startOfDay(for: startDate)
		let rangeEnd = Calendar.current.startOfDay(for: endDate).addingTimeInterval(86400)
		let descriptor = FetchDescriptor<Dive>(
			predicate: #Predicate { $0.date >= rangeStart && $0.date < rangeEnd }
		)
		guard let matchingDives = try? modelContext.fetch(descriptor) else { return }
		for dive in matchingDives {
			dive.trip = trip
		}
	}
}

#Preview("New Trip") {
	TripEntryView(trip: nil)
		.modelContainer(PreviewContainer.container)
}
