//
//  FullScreenPhotoView.swift
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

/// Transient photo descriptor used by `FullScreenPhotoView` so it can display either
/// SwiftData-backed photos or in-memory editor photos through a common interface.
struct DisplayPhoto: Identifiable {
	let id: Int
	let imageData: Data?
	let caption: String
	let originalFilename: String
}

/// Full-screen photo viewer with swipe, forward/back navigation with wrap-around, and page dots.
struct FullScreenPhotoView: View {
	@Environment(\.dismiss) private var dismiss

	let photos: [DisplayPhoto]
	let initialIndex: Int

	@State private var scrolledIndex: Int?

	init(photos: [DisplayPhoto], initialIndex: Int) {
		self.photos = photos
		self.initialIndex = initialIndex
		_scrolledIndex = State(initialValue: min(initialIndex, max(photos.count - 1, 0)))
	}

	private var currentIndex: Int {
		scrolledIndex ?? 0
	}

	var body: some View {
		NavigationStack {
			ZStack {
				Color.black.ignoresSafeArea()

				ScrollView(.horizontal) {
					LazyHStack(spacing: 0) {
						ForEach(0..<photos.count, id: \.self) { index in
							if let data = photos[index].imageData,
							   let image = makeDisplayImage(from: data) {
								image
									.resizable()
									.scaledToFit()
									.containerRelativeFrame([.horizontal, .vertical])
							}
						}
					}
					.scrollTargetLayout()
				}
				.scrollTargetBehavior(.paging)
				.scrollPosition(id: $scrolledIndex)
				.scrollIndicators(.hidden)
				.ignoresSafeArea()

#if os(macOS)
				if photos.count > 1 {
					HStack {
						Button("Previous", systemImage: "chevron.left") {
							withAnimation {
								scrolledIndex = currentIndex == 0 ? photos.count - 1 : currentIndex - 1
							}
						}
						.labelStyle(.iconOnly)
						.font(.title)

						Spacer()

						Button("Next", systemImage: "chevron.right") {
							withAnimation {
								scrolledIndex = currentIndex == photos.count - 1 ? 0 : currentIndex + 1
							}
						}
						.labelStyle(.iconOnly)
						.font(.title)
					}
					.foregroundStyle(.white)
					.padding(.horizontal)
				}
#endif

				VStack {
					Spacer()

					if !photos[currentIndex].caption.isEmpty {
						Text(photos[currentIndex].caption)
							.foregroundStyle(.white)
							.font(.callout)
							.padding(.horizontal)
							.padding(.bottom, 4)
					}

					if photos.count > 1 {
						PageDotsView(count: photos.count, current: currentIndex)
							.padding(.bottom)
					}
				}
			}
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Done", systemImage: "xmark") { dismiss() }
#if !os(macOS)
						.foregroundStyle(.white)
						.labelStyle(.iconOnly)
#endif
				}
				ToolbarItem(placement: .primaryAction) {
					if let data = photos[currentIndex].imageData,
					   let image = makeDisplayImage(from: data) {
						ShareLink(
							item: ImageFileHelper.shareableFile(
								data: data,
								filename: photos[currentIndex].originalFilename
							),
							preview: SharePreview("Photo", image: image)
						)
						.foregroundStyle(.white)
					}
				}
			}
#if !os(macOS)
			.toolbarBackground(.hidden, for: .navigationBar)
#endif
		}
		.onAppear {
			if scrolledIndex != initialIndex {
				scrolledIndex = min(initialIndex, photos.count - 1)
			}
		}
#if os(macOS)
		.frame(
			minWidth: 700, idealWidth: 1100, maxWidth: 1800,
			minHeight: 500, idealHeight: 750, maxHeight: 1400
		)
		.presentationSizing(.fitted)
#endif
	}
}

/// Decodes image data into a SwiftUI `Image` for either UIKit or AppKit platforms.
func makeDisplayImage(from data: Data) -> Image? {
#if canImport(UIKit)
	guard let uiImage = UIImage(data: data) else { return nil }
	return Image(uiImage: uiImage)
#elseif canImport(AppKit)
	guard let nsImage = NSImage(data: data) else { return nil }
	return Image(nsImage: nsImage)
#endif
}

// MARK: - Page Dots

struct PageDotsView: View {
	let count: Int
	let current: Int

	var body: some View {
		HStack(spacing: 6) {
			ForEach(0..<count, id: \.self) { index in
				Circle()
					.fill(index == current ? Color.white : Color.white.opacity(0.4))
					.frame(width: 7, height: 7)
			}
		}
	}
}
