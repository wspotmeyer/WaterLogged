//
//  BuddyDetailView.swift
//  WaterLogged
//
//  Created by John Meyer on 4/4/26.
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

struct BuddyDetailView: View {
	@Environment(\.modelContext) private var modelContext

	let buddy: Buddy
	var onDelete: (() -> Void)?

	@State private var editingBuddy: Buddy?

	private var hasContactInfo: Bool {
		!buddy.telephone.isEmpty || !buddy.email.isEmpty || !buddy.webPage.isEmpty
	}

	private var hasAddress: Bool {
		!buddy.street.isEmpty || !buddy.city.isEmpty || !buddy.state.isEmpty
		|| !buddy.province.isEmpty || !buddy.postalCode.isEmpty || !buddy.country.isEmpty
	}

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 24) {
				BuddyPhotoHeader(buddy: buddy)

				if hasContactInfo {
					ContactInfoSection(buddy: buddy)
				}

				if hasAddress {
					AddressSection(buddy: buddy)
				}

				TripsSection(buddy: buddy)

				DivesSection(buddy: buddy)
			}
			.padding()
			.frame(maxWidth: 700)
			.frame(maxWidth: .infinity)
		}
		.appGradientScrollBackground()
		.navigationTitle(buddy.formattedName)
#if !os(macOS)
		.navigationBarTitleDisplayMode(.inline)
#endif
		.toolbar {
			ToolbarItem(placement: .primaryAction) {
				Button("Edit", systemImage: "pencil") {
					editingBuddy = buddy
				}
			}
		}
		.sheet(item: $editingBuddy) { editing in
			BuddyEntryView(buddy: editing) {
				modelContext.delete(editing)
				onDelete?()
			}
		}
	}
}

// MARK: - Photo Header

private struct BuddyPhotoHeader: View {
	let buddy: Buddy

	var body: some View {
		HStack {
			Spacer()
			BuddyPhoto(photoData: buddy.photoData, size: 120)
			Spacer()
		}
	}
}

// MARK: - Contact Info Section

private struct ContactInfoSection: View {
	let buddy: Buddy

	var body: some View {
		DetailSection(title: "Contact Information") {
			if !buddy.telephone.isEmpty {
				DetailRow(label: "Telephone", value: buddy.telephone)
			}
			if !buddy.email.isEmpty {
				DetailRow(label: "Email", value: buddy.email)
			}
			if !buddy.webPage.isEmpty {
				DetailRow(label: "Web Page", value: buddy.webPage)
			}
		}
	}
}

// MARK: - Address Section

private struct AddressSection: View {
	let buddy: Buddy

	private var cityStateLine: String {
		var parts: [String] = []
		if !buddy.city.isEmpty { parts.append(buddy.city) }
		let region = !buddy.state.isEmpty ? buddy.state : buddy.province
		if !region.isEmpty { parts.append(region) }
		var line = parts.joined(separator: ", ")
		if !buddy.postalCode.isEmpty {
			if !line.isEmpty { line += " " }
			line += buddy.postalCode
		}
		return line
	}

	var body: some View {
		DetailSection(title: "Address") {
			VStack(alignment: .leading, spacing: 4) {
				if !buddy.street.isEmpty {
					Text(buddy.street)
				}
				if !cityStateLine.isEmpty {
					Text(cityStateLine)
				}
				if !buddy.province.isEmpty && !buddy.state.isEmpty {
					Text("Province: \(buddy.province)")
				}
				if !buddy.country.isEmpty {
					Text(buddy.country)
				}
			}
		}
	}
}

// MARK: - Trips Section

private struct TripsSection: View {
	let buddy: Buddy

	@State private var isExpanded = false

	private var trips: [Trip] {
		guard let dives = buddy.dives else { return [] }
		var seenTripIDs: Set<PersistentIdentifier> = []
		var result: [Trip] = []
		for dive in dives.sorted(by: { $0.date < $1.date }) {
			guard let trip = dive.trip, !seenTripIDs.contains(trip.persistentModelID) else { continue }
			seenTripIDs.insert(trip.persistentModelID)
			result.append(trip)
		}
		return result
	}

	var body: some View {
		if !trips.isEmpty {
			Divider()
			GroupBox {
				if isExpanded {
					VStack(spacing: 0) {
						ForEach(trips) { trip in
							NavigationLink {
								TripDetailView(trip: trip)
							} label: {
								HStack {
									Text(LocalizedStringKey(trip.name))
										.lineLimit(1)
									Spacer()
									Text(trip.dateRangeFormatted)
										.lineLimit(1)
									Image(systemName: "chevron.right")
										.font(.caption)
								}
								.padding(.top, 12)
							}
							.buttonStyle(.plain)
						}
					}
					.frame(maxWidth: .infinity, alignment: .leading)
				}
			} label: {
				HStack {
					Text("Trips")
						.font(.title2.weight(.bold))
					Spacer()
					if trips.count > 0 {
						TripCount(count: trips.count, font: .headline)
						Button {
							withAnimation(.smooth) {
								isExpanded.toggle()
							}
						} label: {
							Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
								.imageScale(.small)
								.frame(width: 32, height: 32)
								.contentShape(.rect)
						}
						.buttonStyle(.plain)
						.font(.subheadline)
					}
				}
			}
			.tileBackgroundStyle()

		}
	}
}

// MARK: - Dives Section

private struct DivesSection: View {
	let buddy: Buddy

	@State private var isExpanded = false

	var body: some View {
		if let dives = buddy.dives, !dives.isEmpty {
			GroupBox {
				if isExpanded {
					VStack(spacing: 0) {
						ForEach(dives.sorted(by: { $0.date < $1.date })) { dive in
							NavigationLink {
								DiveDetailView(dive: dive)
							} label: {
								HStack {
									Text(LocalizedStringKey(dive.displayTitle))
										.lineLimit(1)
									Spacer()
									Text(dive.date.formatted(date: .abbreviated, time: .omitted))
										.lineLimit(1)
									Image(systemName: "chevron.right")
										.font(.caption)
								}
								.padding(.top, 12)
							}
							.buttonStyle(.plain)
						}
					}
					.frame(maxWidth: .infinity, alignment: .leading)
				}
			} label: {
				HStack {
					Text("Dives")
						.font(.title2.weight(.bold))
					Spacer()
					if dives.count > 0 {
						TimeCount(seconds: buddy.totalDiveTimeSeconds, font: .headline)
						DiveCount(count: dives.count, font: .headline)
						Button {
							withAnimation(.smooth) {
								isExpanded.toggle()
							}
						} label: {
							Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
								.imageScale(.small)
								.frame(width: 32, height: 32)
								.contentShape(.rect)
						}
						.buttonStyle(.plain)
						.font(.subheadline)
					}
				}
			}
			.tileBackgroundStyle()

		}
	}
}

#Preview {
	BuddyDetailView(buddy: Buddy(givenName: "Maria", familyName: "Garcia"))
		.modelContainer(PreviewContainer.container)
}
