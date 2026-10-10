//
//  CircularPhotoPicker.swift
//  WaterLogged
//
//  Created by John Meyer on 10/4/26.
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

/// Photo controls for a person (buddy or log book owner): a circular preview with
/// a Remove button when a photo is set, otherwise Photos and Files pickers.
struct CircularPhotoPicker: View {
	@Binding var photoData: Data?
	@Binding var photoItem: PhotosPickerItem?
	@Binding var showingFileImporter: Bool

	var body: some View {
		if let photoData, let image = makeDisplayImage(from: photoData) {
			HStack {
				Spacer()
				image
					.resizable()
					.scaledToFill()
					.frame(width: 100, height: 100)
					.clipShape(.circle)
				Spacer()
			}
			Button("Remove Photo", systemImage: "trash", role: .destructive) {
				self.photoData = nil
				photoItem = nil
			}
		} else {
			PhotosPicker(selection: $photoItem, matching: .images) {
				Label("Choose from Photos", systemImage: "photo.on.rectangle")
			}
			Button("Choose from Files", systemImage: "folder") {
				showingFileImporter = true
			}
		}
	}
}
