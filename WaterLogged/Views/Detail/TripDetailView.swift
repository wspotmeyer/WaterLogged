//
//  TripDetailView.swift
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

//
//  TripDetailView.swift
//  WaterLogged
//
//  Created by John Meyer on 4/20/26.
//

import SwiftUI
import SwiftData
import MapKit

struct TripDetailView: View {
	@Environment(\.modelContext) private var modelContext

	let trip: Trip
	var onDelete: (() -> Void)?

	@State private var editingTrip: Trip?
	@State private var showingPhotoEditor = false
	@State private var isDivesExpanded = false

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 24) {

				// Header
				VStack(alignment: .leading, spacing: 6) {
					Text(LocalizedStringKey(trip.name))
						.font(.title.bold())
					if !trip.location.isEmpty {
						Label(trip.location, systemImage: "map")
							.font(.subheadline)
					}
					Label(trip.dateRangeFormatted, systemImage: "calendar")
						.font(.subheadline)
				}

				if hasDetails {
					Divider()

					// Details
					DetailSection(title: "Details") {
						if !trip.address.isEmpty {
							DetailRow(label: "Residence", value: trip.address)
						}
						if let url = trip.url {
							DetailRowContent {
								Link("Trip Details", destination: url)
							}
							.padding(.top, 2)
						}
					}
				}

				// Map
				if let lat = trip.latitude, let lon = trip.longitude {
					CoordinateMapView(latitude: lat, longitude: lon) {
						Marker(!trip.address.isEmpty ? trip.address : trip.name, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
					}
				}

				VStack(alignment: .leading, spacing: 10) {
					HStack {
						Text("Photos")
							.font(.title2.weight(.bold))
						Spacer()
						Button("Edit Photos", systemImage: "pencil") {
							showingPhotoEditor = true
						}
						.labelStyle(.iconOnly)
					}
					if let photos = trip.photos, !photos.isEmpty {
						PhotoCarouselView(photos: photos)
					} else {
						Text("No photos yet.")
					}
				}

				// Notes
				if !trip.notes.isEmpty {
					DetailSection(title: "Notes") {
						Text(LocalizedStringKey(trip.notes))
					}
				}

				// Dives
				if !sortedDives.isEmpty {
					Divider()

					GroupBox {
						if isDivesExpanded {
							ForEach(sortedDives) { dive in
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
									.padding(.top, 4)
								}
								.buttonStyle(.plain)
							}
						}
					} label: {
						HStack {
							Text("Dives")
								.font(.title2.weight(.bold))
							Spacer()
							if sortedDives.count > 0 {
								TimeCount(seconds: trip.totalDiveTimeSeconds, font: .headline)
								DiveCount(count: sortedDives.count, font: .headline)
								Button {
									withAnimation(.smooth) {
										isDivesExpanded.toggle()
									}
								} label: {
									Image(systemName: isDivesExpanded ? "chevron.down" : "chevron.right")
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
			.padding()
			.frame(maxWidth: 700)
			.frame(maxWidth: .infinity)
		}
		.appGradientScrollBackground()
		.toolbar {
			ToolbarItem(placement: .primaryAction) {
				Button("Edit", systemImage: "pencil") {
					editingTrip = trip
				}
			}
		}
		.sheet(item: $editingTrip) { editing in
			TripEntryView(trip: editing) {
				modelContext.delete(editing)
				onDelete?()
			}
		}
		.sheet(isPresented: $showingPhotoEditor) {
			PhotoEditSheet(existingPhotos: trip.photos ?? []) { entries in
				savePhotos(entries)
			}
		}
	}

	private func savePhotos(_ entries: [PhotoEntry]) {
		if let existing = trip.photos {
			for photo in existing {
				modelContext.delete(photo)
			}
		}
		for (index, entry) in entries.enumerated() {
			let photo = Photo(imageData: entry.imageData, caption: entry.caption, sortOrder: index, originalFilename: entry.originalFilename)
			photo.trip = trip
			modelContext.insert(photo)
		}
		try? modelContext.save()
	}

	private var hasDetails: Bool {
		!trip.address.isEmpty
		|| trip.latitude != nil
		|| !trip.urlString.isEmpty
	}

	private var sortedDives: [Dive] {
		(trip.dives ?? []).sorted { $0.date < $1.date }
	}

	private func formatCoordinates(lat: Double, lon: Double) -> String {
		let latDir = lat >= 0 ? "N" : "S"
		let lonDir = lon >= 0 ? "E" : "W"
		return "\(abs(lat).formatted(.number.precision(.fractionLength(4))))° \(latDir), \(abs(lon).formatted(.number.precision(.fractionLength(4))))° \(lonDir)"
	}
}

#Preview {
	let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
	// swiftlint:disable:next force_try
	let container = try! ModelContainer(for: Trip.self, Dive.self, DiveSite.self, GasMix.self, DepthSample.self, Equipment.self, ServiceRecord.self, Certification.self, Buddy.self, Photo.self, Tank.self, configurations: config)
	let trip = Trip(
		name: "Cozumel Spring Break",
		startDate: Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 1))!,
		endDate: Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 7))!,
		location: "Cozumel, Mexico",
		address: "Cozumel, Quintana Roo, Mexico",
		latitude: 20.4318,
		longitude: -86.9203,
		notes: "Spring break diving trip with the family."
	)
	container.mainContext.insert(trip)
	return NavigationStack {
		TripDetailView(trip: trip)
	}
	.modelContainer(container)
}
