//
//  PhotoEditSheet.swift
//  WaterLogged
//
//  Created by John Meyer on 6/19/26.
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
import PhotosUI

/// A sheet for managing a collection of photos: add (from the photo library or files),
/// drag-to-reorder, and delete.
///
/// Reorder uses `reorderable()` / `reorderContainer(for:)`, which is its own drag container and
/// drop destination — the tiles need no `draggable`/`Transferable` plumbing of their own. The grid
/// must stay a standalone `ScrollView` + `LazyVGrid`: the modifiers don't engage inside a
/// `Form`/`List`, whose rows swallow the lift gesture.
///
/// The sheet works on a private array of `PhotoEntry` values loaded from the supplied photos,
/// and reports the edited result through `onSave` so the caller can persist it to SwiftData.
struct PhotoEditSheet: View {
	let existingPhotos: [Photo]
	let onSave: ([PhotoEntry]) -> Void

	@Environment(\.dismiss) private var dismiss

	@State private var photoEntries: [PhotoEntry] = []
	@State private var photoPickerItems: [PhotosPickerItem] = []
	@State private var showingFileImporter = false

	private let columns = [GridItem(.adaptive(minimum: 120), spacing: 12)]
	var body: some View {
		NavigationStack {
			ScrollView {
				if photoEntries.count > 1 {
					Text("Drag a photo to move it into place. Tap the trash icon to remove one.")
						.font(.footnote)
						.foregroundStyle(.secondary)
						.frame(maxWidth: .infinity, alignment: .leading)
						.padding(.horizontal)
						.padding(.top, 8)
				}
				LazyVGrid(columns: columns, spacing: 12) {
					ForEach(photoEntries) { entry in
						PhotoEditTile(entry: entry, photoEntries: $photoEntries)
					}
					.reorderable()
				}
				.reorderContainer(for: PhotoEntry.self, isEnabled: photoEntries.count > 1) { difference in
					withAnimation {
						difference.apply(to: &photoEntries)
					}
				}
				.padding()
			}
			.scrollIndicators(.hidden)
			.appGradientScrollBackground()
			.overlay {
				if photoEntries.isEmpty {
					ContentUnavailableView(
						"No Photos",
						systemImage: "photo.badge.plus",
						description: Text("Add photos from your library or files.")
					)
				}
			}
			.navigationTitle("Edit Photos")
#if !os(macOS)
			.navigationBarTitleDisplayMode(.inline)
#endif
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel", systemImage: "xmark") { dismiss() }
				}
				ToolbarItem(placement: .confirmationAction) {
					Button("Save", systemImage: "checkmark") {
						onSave(photoEntries)
						dismiss()
					}
					.buttonStyle(.borderedProminent)
				}
			}
			.safeAreaInset(edge: .bottom) {
				HStack {
					PhotosPicker(selection: $photoPickerItems, matching: .images) {
						Label("Choose from Photos", systemImage: "photo.on.rectangle")
					}
					Spacer()
					Button("Choose from Files", systemImage: "folder") {
						showingFileImporter = true
					}
				}
				.padding()
				.background(.bar)
			}
		}
		.onAppear(perform: loadExistingPhotos)
		.onChange(of: photoPickerItems) { _, newItems in
			Task { await loadPhotoPickerItems(newItems) }
		}
		.fileImporter(
			isPresented: $showingFileImporter,
			allowedContentTypes: ImageFileHelper.importableTypes,
			allowsMultipleSelection: true
		) { result in
			loadPhotoFiles(from: result)
		}
#if os(macOS)
		.frame(minWidth: 480, idealWidth: 560, minHeight: 400, idealHeight: 520)
#endif
	}

	// MARK: - Loading

	private func loadExistingPhotos() {
		guard photoEntries.isEmpty else { return }
		photoEntries = existingPhotos
			.sorted { $0.sortOrder < $1.sortOrder }
			.compactMap { photo in
				guard photo.imageData != nil else { return nil }
				return PhotoEntry(from: photo)
			}
	}

	private func loadPhotoPickerItems(_ items: [PhotosPickerItem]) async {
		for item in items {
			if let data = try? await item.loadTransferable(type: Data.self) {
				photoEntries.append(PhotoEntry(imageData: data, originalFilename: ImageFileHelper.defaultFilename(for: data)))
			}
		}
		photoPickerItems.removeAll()
	}

	private func loadPhotoFiles(from result: Result<[URL], Error>) {
		guard let urls = try? result.get() else { return }
		for url in urls {
			guard url.startAccessingSecurityScopedResource() else { continue }
			defer { url.stopAccessingSecurityScopedResource() }
			if let data = try? Data(contentsOf: url) {
				photoEntries.append(PhotoEntry(imageData: data, originalFilename: url.lastPathComponent))
			}
		}
	}
}

// MARK: - Photo Tile

/// A single reorderable, deletable photo tile. Rendered as a plain image (not a `Button`) so the
/// enclosing reorder container owns the lift gesture; delete is a small corner button. The tile
/// carries no drag modifiers of its own — `reorderable()` on the enclosing `ForEach` makes it
/// draggable through the container.
///
/// **The body must stay unconditional.** A reorderable child built from an `if`/`else` or `switch`
/// in a `@ViewBuilder` crashes the reorder container at drag-lift, so `thumbnail` resolves to a
/// concrete `Image` with `??` rather than branching.
private struct PhotoEditTile: View {
	let entry: PhotoEntry
	@Binding var photoEntries: [PhotoEntry]

	/// Resolved with `??` instead of an `if let` so the tile is a single, unconditional view.
	private var thumbnail: Image {
		makeDisplayImage(from: entry.imageData) ?? Image(systemName: "photo")
	}

	var body: some View {
		thumbnail
			.resizable()
			.scaledToFill()
			.frame(width: 120, height: 90)
			.background(.quaternary)
			.clipShape(.rect(cornerRadius: 8))
			.overlay(alignment: .topTrailing) {
				Button("Delete Photo", systemImage: "trash.circle.fill", role: .destructive) {
					withAnimation {
						photoEntries.removeAll { $0.id == entry.id }
					}
				}
				.labelStyle(.iconOnly)
				.buttonStyle(.borderless)
				.symbolRenderingMode(.palette)
				.foregroundStyle(.red, .white.opacity(0.8))
				.padding(4)
			}
			.contentShape(.rect)
	}
}

// MARK: - Reorder Difference

extension ReorderDifference where CollectionID == ReorderableSingleCollectionIdentifier {
	/// Applies a single-collection reorder by lifting the moved elements out in one in-place pass
	/// and re-inserting them at the difference's destination.
	fileprivate func apply<C>(to collection: inout C)
	where C: RangeReplaceableCollection, C.Element: Identifiable, C.Element.ID == ItemID {
		let moving = Set(sources)
		guard !moving.isEmpty else { return }

		var moved: [C.Element] = []
		moved.reserveCapacity(moving.count)
		collection.removeAll { element in
			guard moving.contains(element.id) else { return false }
			moved.append(element)
			return true
		}

		switch destination.position {
			case .before(let id):
				let index = collection.firstIndex { $0.id == id } ?? collection.endIndex
				collection.insert(contentsOf: moved, at: index)
			case .end:
				collection.append(contentsOf: moved)
		}
	}
}

// MARK: - Photo Entry

/// Transient struct used to manage photos during editing before persisting to SwiftData.
struct PhotoEntry: Identifiable {
	let id: UUID
	var imageData: Data
	var caption: String
	var originalFilename: String

	init(id: UUID = UUID(), imageData: Data, caption: String = "", originalFilename: String = "") {
		self.id = id
		self.imageData = imageData
		self.caption = caption
		self.originalFilename = originalFilename
	}

	init(from photo: Photo) {
		self.id = UUID()
		self.imageData = photo.imageData ?? Data()
		self.caption = photo.caption
		self.originalFilename = photo.originalFilename
	}
}
