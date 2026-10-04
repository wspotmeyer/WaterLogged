//
//  DeleteOffsetsConfirmation.swift
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

extension View {
	/// Confirms a swipe- or edit-mode delete in a list. The alert shows while
	/// `offsets` is non-nil; Delete passes them to `onDelete`, and either button
	/// clears them. `message` builds the body text from the number of rows.
	func deleteOffsetsConfirmation(
		_ title: LocalizedStringKey,
		offsets: Binding<IndexSet?>,
		message: @escaping (Int) -> Text,
		onDelete: @escaping (IndexSet) -> Void
	) -> some View {
		alert(
			title,
			isPresented: Binding(
				get: { offsets.wrappedValue != nil },
				set: { if !$0 { offsets.wrappedValue = nil } }
			),
			presenting: offsets.wrappedValue
		) { pending in
			Button("Delete", role: .destructive) {
				onDelete(pending)
				offsets.wrappedValue = nil
			}
			Button("Cancel", role: .cancel) {
				offsets.wrappedValue = nil
			}
		} message: { pending in
			message(pending.count)
		}
	}
}
