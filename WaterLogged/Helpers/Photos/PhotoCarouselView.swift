//
//  PhotoCarouselView.swift
//  WaterLogged
//
//  Created by John Meyer on 4/25/26.
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

/// A read-only photo carousel that displays sorted photos with tap-to-fullscreen.
struct PhotoCarouselView: View {
	let photos: [Photo]

	@State private var selectedPhoto: PhotoSelection?

	private var sortedPhotos: [Photo] {
		photos.sorted { $0.sortOrder < $1.sortOrder }
	}

	var body: some View {
		let sorted = sortedPhotos
		if !sorted.isEmpty {
			let displayPhotos = sorted.enumerated().map { index, photo in
				DisplayPhoto(
					id: index,
					imageData: photo.imageData,
					caption: photo.caption,
					originalFilename: photo.originalFilename
				)
			}
			ScrollView(.horizontal) {
				LazyHStack(spacing: 12) {
					ForEach(displayPhotos) { photo in
						if let data = photo.imageData, let image = makeDisplayImage(from: data) {
							Button {
								selectedPhoto = PhotoSelection(id: photo.id)
							} label: {
								image
									.resizable()
									.scaledToFill()
									.frame(width: 160, height: 120)
									.clipShape(.rect(cornerRadius: 8))
							}
							.buttonStyle(.plain)
						}
					}
				}
				.padding(.horizontal)
			}
			.scrollIndicators(.hidden)
			.frame(height: 120)
#if os(macOS)
			.sheet(item: $selectedPhoto) { selection in
				FullScreenPhotoView(photos: displayPhotos, initialIndex: selection.id)
			}
#else
			.fullScreenCover(item: $selectedPhoto) { selection in
				FullScreenPhotoView(photos: displayPhotos, initialIndex: selection.id)
			}
#endif
		}
	}
}

// MARK: - Photo Selection

private struct PhotoSelection: Identifiable {
	let id: Int
}
