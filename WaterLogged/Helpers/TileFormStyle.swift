//
//  TileFormStyle.swift
//  WaterLogged
//
//  Created by John Meyer on 10/5/26.
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

/// Draws a `Form` as a scrolling stack of the app's tiles: each section's
/// header, then its rows inside a rounded rectangle filled with the shared tile
/// color and divided by separators, then its footer.
///
/// This exists for macOS. The built-in grouped form style there ignores
/// `listRowBackground` (and `listRowInsets`), painting its own light,
/// translucent section fill instead. Over the dark app gradient that fill
/// leaves entry rows hard to read, whereas iOS and iPadOS honor
/// `tileListRowBackground()` and show dark sections. Drawing the sections
/// directly, as ``TileGroupBoxStyle`` does for `GroupBox`, makes the Mac match.
///
/// Because the rows no longer get the system form's row treatment, the style
/// restores the iOS look for the common controls: plain text fields, switch
/// toggles, and trailing-aligned `LabeledContent`. Row and header metrics
/// approximate the system grouped form.
struct TileFormStyle: FormStyle {
	func makeBody(configuration: Configuration) -> some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 20) {
				ForEach(sections: configuration.content) { section in
					VStack(alignment: .leading, spacing: 6) {
						if !section.header.isEmpty {
							HStack { section.header }
								.font(.headline)
								.padding(.horizontal, 10)
						}
						VStack(spacing: 0) {
							ForEach(subviews: section.content) { row in
								row
									.frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
									.padding(.horizontal, 10)
									.padding(.vertical, 8)
								if row.id != section.content.last?.id {
									Divider()
										.padding(.horizontal, 10)
								}
							}
						}
						.tileBackground()
						if !section.footer.isEmpty {
							HStack { section.footer }
								.font(.footnote)
								.foregroundStyle(.secondary)
								.padding(.horizontal, 10)
						}
					}
				}
			}
			.padding()
		}
		.textFieldStyle(.plain)
		.toggleStyle(.switch)
		.labeledContentStyle(.trailing)
	}
}

extension FormStyle where Self == TileFormStyle {
	/// A form whose sections are drawn as the app's tiles. See ``TileFormStyle``.
	static var tile: TileFormStyle { TileFormStyle() }
}

extension View {
	/// The app's standard form style: ``TileFormStyle`` on macOS, where the
	/// grouped style ignores row backgrounds, and the grouped style elsewhere,
	/// where `tileListRowBackground()` tints its rows.
	func appFormStyle() -> some View {
#if os(macOS)
		formStyle(.tile)
#else
		formStyle(.grouped)
#endif
	}
}

#Preview {
	Form {
		Section {
			TextField("Name", text: .constant("Air"))
			LabeledContent("O\u{2082} %") {
				TextField("Oxygen", value: .constant(21.0), format: .number)
					.labelsHidden()
					.multilineTextAlignment(.trailing)
			}
			Toggle("Favorite", isOn: .constant(true))
			Picker("Water", selection: .constant(1)) {
				Text("Salt").tag(1)
			}
			DatePicker("Date", selection: .constant(.now))
		} header: {
			Text("Section")
		} footer: {
			Text("A footer.")
		}
	}
	.formStyle(.tile)
	.appGradientScrollBackground()
}
