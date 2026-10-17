//
//  DetailHeader.swift
//  WaterLogged
//
//  Created by John Meyer on 10/9/26.
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

import SwiftData
import SwiftUI

/// The title block at the top of a detail page, with the record's cover photo
/// behind it.
///
/// The photo runs edge to edge and up under the toolbar, scrolls away with the
/// title, and fades into the
/// app gradient at its bottom. With a photo the block is given a minimum
/// height and the title sits at its bottom, over the fading part. Without one
/// the block lays out exactly like a plain padded header.
///
/// Place it as the first child of the page's scroll content, outside the
/// padding the rest of the page uses, and pad the content below it with
/// `.padding([.horizontal, .bottom])`.
struct DetailHeader<Content: View>: View {
	/// The record's cover photo, from `Photo.cover(of:)`.
	let photo: Photo?
	/// Caps the title's width on pages whose content is width-limited, so it
	/// lines up with the content below. The photo itself still runs full width.
	var maxContentWidth: CGFloat?
	@ViewBuilder let content: Content

	/// Minimum height of the block when it has a photo, not counting the part
	/// that extends up under the toolbar. Applies on narrow widths (iPhone).
	private static var minimumPhotoHeight: CGFloat { 220 }
	/// Cap on the photo-driven height, so a very wide Mac window doesn't push
	/// the page content off the bottom of the screen.
	private static var maximumPhotoHeight: CGFloat { 480 }
	/// Height of the block as a fraction of its width. Wider displays get a
	/// taller block, so they show more of the photo instead of a thin strip.
	private static var heightToWidthRatio: CGFloat { 0.4 }
	/// How far the photo extends above the header, under the toolbar and
	/// status bar. Generous enough for the tallest bar (iPhone); any excess is
	/// clipped by the scroll view and only shows when pulling down past the top.
	private static var toolbarOverlap: CGFloat { 150 }
	/// How far the photo extends past each side, to cover the landscape
	/// iPhone's side insets. Clipped by the scroll view where there are none.
	private static var sideOverlap: CGFloat { 80 }
	/// Longest side of the decoded photo, in pixels: sharp at full width on a
	/// large Mac window without decoding the full camera original.
	private static var maxPixelSize: Int { 2400 }

	@State private var image: CGImage?
	/// The block's full width, which drives its minimum height with a photo.
	@State private var width: CGFloat = 0

	var body: some View {
		content
			// Keep the content at its natural height. The minimum-height frame
			// below would otherwise hand its spare height to any vertically
			// flexible child, stretching e.g. `DiveNumberBadge`, which fills its
			// row's height to match the title beside it.
			.fixedSize(horizontal: false, vertical: true)
			.padding([.horizontal, .top])
			// The gap the detail pages leave between sections, kept inside the
			// header so the photo fades out below the last line of text.
			.padding(.bottom, 24)
			.frame(maxWidth: maxContentWidth ?? .infinity, alignment: .leading)
			.frame(
				maxWidth: .infinity,
				minHeight: image == nil ? nil : Self.photoHeight(forWidth: width),
				alignment: .bottom
			)
			// The width doesn't depend on the height set above, so measuring it
			// here can't feed back into a layout loop.
			.onGeometryChange(for: CGFloat.self) { proxy in
				proxy.size.width
			} action: { newWidth in
				width = newWidth
			}
			.background {
				if let image {
					// `ignoresSafeArea` has no effect inside a ScrollView, whose
					// safe area becomes a content inset. The scroll view itself
					// still runs under the toolbar and (in landscape) beside the
					// Dynamic Island, so extend the photo past the header's top and
					// sides to fill that space.
					DetailHeaderPhoto(image: image)
						.padding(.top, -Self.toolbarOverlap)
						.padding(.horizontal, -Self.sideOverlap)
				}
			}
			.task(id: photo?.persistentModelID) {
				image = await loadImage()
			}
	}

	/// The block's minimum height with a photo: proportional to its width,
	/// clamped between the minimum and maximum photo heights.
	private static func photoHeight(forWidth width: CGFloat) -> CGFloat {
		min(max(width * heightToWidthRatio, minimumPhotoHeight), maximumPhotoHeight)
	}

	/// Decodes a downsized copy of the cover photo off the main thread.
	private func loadImage() async -> CGImage? {
		guard let photo, photo.isLive, let data = photo.imageData else { return nil }
		let maxPixelSize = Self.maxPixelSize
		return await Task.detached(priority: .userInitiated) {
			HeaderPhotoLoader.thumbnail(from: data, maxPixelSize: maxPixelSize)
		}.value
	}
}
