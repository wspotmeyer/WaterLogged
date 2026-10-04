//
//  ToolTile.swift
//  WaterLogged
//
//  Created by John Meyer on 7/7/26.
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

/// A large tappable tile in `ToolsView`: an icon, a title, and a short
/// description of the action. Filled with the shared tile background so it
/// matches the app's cards and lets the background gradient show through.
struct ToolTile: View {
	let title: String
	let description: String
	let systemImage: String
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			VStack(alignment: .leading, spacing: 8) {
				HStack {
					Image(systemName: systemImage)
						.font(.title)
						.foregroundStyle(.tint)
					Text(title)
						.font(.headline)
				}
				Text(description)
					.font(.caption)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
				Spacer(minLength: 0)
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
			.multilineTextAlignment(.leading)
			.padding()
			.tileBackground()
			.contentShape(.rect(cornerRadius: 12))
		}
		.buttonStyle(.plain)
	}
}

#Preview {
	ToolTile(
		title: "Bulk Updater",
		description: "Apply changes to many dives at once.",
		systemImage: "square.and.arrow.up.on.square"
	) {}
		.frame(width: 220, height: 160)
		.padding()
}
