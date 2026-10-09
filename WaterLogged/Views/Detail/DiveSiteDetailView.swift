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

	var body: some View {
		if site.isLive {
			ScrollView {
				VStack(spacing: 0) {
					// Header
					DetailHeader(photo: Photo.cover(of: site.photos), maxContentWidth: 700) {
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
					}

					VStack(alignment: .leading, spacing: 24) {
						Divider()

						DiveSiteMapView(diveSite: site)
							.id(site.persistentModelID)

						VStack(alignment: .leading, spacing: 10) {
							HStack {
								Text("Photos")
									.font(.title2.bold())
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
										.foregroundStyle(.secondary)
								}
							}
						}

						TripsSection(dives: site.dives)

						DivesSection(dives: site.dives)
					}
					.padding([.horizontal, .bottom])
					.frame(maxWidth: 700)
					.frame(maxWidth: .infinity)
				}
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
					Photo.replace(site.photos, with: entries, in: modelContext) { $0.diveSite = site }
				}
			}
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
