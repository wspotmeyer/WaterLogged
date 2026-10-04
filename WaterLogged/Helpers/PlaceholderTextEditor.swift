//
//  PlaceholderTextEditor.swift
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

/// A multi-line `TextEditor` that shows a dimmed placeholder while empty,
/// used for the notes and warranty fields in entry forms.
struct PlaceholderTextEditor: View {
	let placeholder: LocalizedStringKey
	@Binding var text: String
	var minHeight: CGFloat = 100

	/// Footer shown under free-text fields whose contents render as Markdown.
	static let markdownHint: LocalizedStringKey = "You can use text formatting (bold, italics, links, etc.) using inline Markdown syntax."

	var body: some View {
		ZStack(alignment: .topLeading) {
			if text.isEmpty {
				Text(placeholder)
					.foregroundStyle(.tertiary)
					.padding(.top, 8)
					.padding(.leading, 4)
			}
			TextEditor(text: $text)
				.frame(minHeight: minHeight)
		}
	}
}
