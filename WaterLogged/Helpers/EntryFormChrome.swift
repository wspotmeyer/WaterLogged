//
//  EntryFormChrome.swift
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

/// The presentation shared by every entry form: grouped form style (tile form
/// style on macOS), the app gradient behind it, an inline title on iOS, and
/// Cancel / Save toolbar buttons.
struct EntryFormChrome: ViewModifier {
	let title: LocalizedStringKey
	let canSave: Bool
	let onSave: () -> Void
	let onCancel: () -> Void

	func body(content: Content) -> some View {
		content
			.appFormStyle()
			.appGradientScrollBackground()
			.navigationTitle(title)
#if os(iOS)
			.navigationBarTitleDisplayMode(.inline)
#endif
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel", systemImage: "xmark", action: onCancel)
				}
				ToolbarItem(placement: .confirmationAction) {
					Button("Save", systemImage: "checkmark", action: onSave)
						.buttonStyle(.borderedProminent)
						.disabled(!canSave)
				}
			}
	}
}

extension View {
	/// Applies the standard entry-form presentation. `onSave` runs when Save is
	/// tapped (callers that close the sheet on save call `dismiss()` themselves);
	/// `onCancel` runs when Cancel is tapped.
	func entryFormChrome(
		_ title: LocalizedStringKey,
		canSave: Bool = true,
		onSave: @escaping () -> Void,
		onCancel: @escaping () -> Void
	) -> some View {
		modifier(EntryFormChrome(title: title, canSave: canSave, onSave: onSave, onCancel: onCancel))
	}
}
