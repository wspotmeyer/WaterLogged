//
//  DiveSiteEntryView.swift
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

struct DiveSiteEntryView: View {
	@Environment(\.modelContext) private var modelContext
	@Environment(\.dismiss) private var dismiss

	let site: DiveSite?
	var onSave: ((DiveSite) -> Void)?
	var onDelete: (() -> Void)?

	@State private var name = ""
	@State private var country = ""
	@State private var region = ""
	@State private var latitude = ""
	@State private var longitude = ""
	@State private var notes = ""

	@State private var showingDeleteConfirmation = false

	private var isEditing: Bool { site != nil }

	var body: some View {
		NavigationStack {
			Form {
				Group {
					Section("Location") {
						TextField("Site Name", text: $name)
						TextField("Country", text: $country)
						TextField("Region", text: $region)
					}
					Section("Coordinates") {
						LabeledContent("Latitude") {
							TextField("Latitude", text: $latitude, prompt: Text("(optional)"))
								.labelsHidden()
#if !os(macOS)
								.keyboardType(.numbersAndPunctuation)
#endif
								.multilineTextAlignment(.trailing)
						}
						LabeledContent("Longitude") {
							TextField("Longitude", text: $longitude, prompt: Text("(optional)"))
								.labelsHidden()
#if !os(macOS)
								.keyboardType(.numbersAndPunctuation)
#endif
								.multilineTextAlignment(.trailing)
						}
					}
					Section(header: Text("Notes"), footer: Text(PlaceholderTextEditor.markdownHint)) {
						PlaceholderTextEditor(placeholder: "Notes", text: $notes)
					}
					if isEditing {
						DeleteItemSection(title: "Delete This Dive Site", isConfirming: $showingDeleteConfirmation)
					}
				}
				.tileListRowBackground()
			}
			.entryFormChrome(
				site == nil ? "New Dive Site" : "Edit Dive Site",
				canSave: !name.isEmpty,
				onSave: {
					save()
					dismiss()
				},
				onCancel: { dismiss() }
			)
			.onAppear {
				if let site {
					name = site.name
					country = site.country
					region = site.region
					latitude = site.latitude.map { String($0) } ?? ""
					longitude = site.longitude.map { String($0) } ?? ""
					notes = site.notes
				}
			}
			.deleteConfirmation(
				"Delete This Dive Site?",
				isPresented: $showingDeleteConfirmation,
				message: "This will permanently delete this dive site. Any dives at this site will no longer have a site assigned."
			) {
				dismiss()
				onDelete?()
			}
		}
#if os(macOS)
		.frame(minWidth: 400, idealWidth: 480, minHeight: 350, idealHeight: 450)
#endif
	}

	private func save() {
		let lat = Double(latitude)
		let lon = Double(longitude)

		if let site {
			site.name = name
			site.country = country
			site.region = region
			site.latitude = lat
			site.longitude = lon
			site.notes = notes
			onSave?(site)
		} else {
			let newSite = DiveSite(
				name: name,
				country: country,
				region: region,
				latitude: lat,
				longitude: lon,
				notes: notes
			)
			modelContext.insert(newSite)
			onSave?(newSite)
		}
	}
}

#Preview("New Dive Site") {
	DiveSiteEntryView(site: nil)
		.modelContainer(PreviewContainer.container)
}
