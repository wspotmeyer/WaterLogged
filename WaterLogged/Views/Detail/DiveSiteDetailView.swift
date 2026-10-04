//
//  DiveSiteDetailView.swift
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

struct DiveSiteDetailView: View {
	@Environment(\.modelContext) private var modelContext

	let site: DiveSite
	var onDelete: (() -> Void)?

	@State private var editingSite: DiveSite?
	@State private var showingPhotoEditor = false
	@State private var isDivesExpanded = false

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 24) {

				// Header
				VStack(alignment: .leading, spacing: 6) {
					Text(LocalizedStringKey(site.name))
						.font(.title.bold())

					if !site.region.isEmpty || !site.country.isEmpty {
						HStack(spacing: 12) {
							if !site.region.isEmpty {
								Label(site.region, systemImage: "map")
							}
							if !site.country.isEmpty {
								if let flag = CountryFlag.emoji(for: site.country) {
									Text("\(flag) \(site.country)")
								} else {
									Label(site.country, systemImage: "globe")
								}
							}
						}
						.font(.subheadline)
					}
				}

				Divider()

				DiveSiteMapView(diveSite: site)
					.id(site.persistentModelID)

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
					if let photos = site.photos, !photos.isEmpty {
						PhotoCarouselView(photos: photos)
					} else {
						Text("No photos yet.")
					}
				}

				if !site.notes.isEmpty {
					VStack(alignment: .leading, spacing: 10) {
						DetailSection(title: "Notes") {
							Text(LocalizedStringKey(site.notes))
						}
					}
				}

				TripsSection(site: site)

				if let dives = site.dives, !dives.isEmpty {

					GroupBox {
						if isDivesExpanded {
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
								TimeCount(seconds: site.totalDiveTimeSeconds, font: .headline)
								DiveCount(count: dives.count, font: .headline)
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
					editingSite = site
				}
			}
		}
		.sheet(item: $editingSite) { editing in
			DiveSiteEntryView(site: editing, onDelete: {
				modelContext.delete(editing)
				onDelete?()
			})
		}
		.sheet(isPresented: $showingPhotoEditor) {
			PhotoEditSheet(existingPhotos: site.photos ?? []) { entries in
				savePhotos(entries)
			}
		}
	}

	private func savePhotos(_ entries: [PhotoEntry]) {
		if let existing = site.photos {
			for photo in existing {
				modelContext.delete(photo)
			}
		}
		for (index, entry) in entries.enumerated() {
			let photo = Photo(imageData: entry.imageData, caption: entry.caption, sortOrder: index, originalFilename: entry.originalFilename)
			photo.diveSite = site
			modelContext.insert(photo)
		}
		try? modelContext.save()
	}
}

// MARK: - Trips Section

private struct TripsSection: View {
	let site: DiveSite

	@State private var isExpanded = false

	/// The trips this site's dives belong to, in dive-date order, without duplicates.
	private var trips: [Trip] {
		guard let dives = site.dives else { return [] }
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

#Preview {
	@Previewable @State var site: DiveSite = {
		let context = PreviewContainer.container.mainContext
		let descriptor = FetchDescriptor<DiveSite>(predicate: #Predicate { $0.name == "Palancar Reef" })
		return (try? context.fetch(descriptor).first) ?? DiveSite(name: "Sample Site")
	}()

	NavigationStack {
		DiveSiteDetailView(site: site)
	}
	.modelContainer(PreviewContainer.container)
}
