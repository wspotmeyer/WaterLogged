//
//  DeleteItemSection.swift
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

/// The destructive "Delete This …" button shown at the bottom of an entry form
/// when editing an existing record. It only raises the confirmation; pair it
/// with `deleteConfirmation(_:isPresented:message:onDelete:)`.
struct DeleteItemSection: View {
	let title: LocalizedStringKey
	@Binding var isConfirming: Bool

	var body: some View {
		Section {
			Button(title, role: .destructive) {
				isConfirming = true
			}
		}
	}
}

extension View {
	/// The confirmation alert behind a `DeleteItemSection`: a destructive Delete
	/// button that runs `onDelete`, plus Cancel.
	func deleteConfirmation(
		_ title: LocalizedStringKey,
		isPresented: Binding<Bool>,
		message: LocalizedStringKey,
		onDelete: @escaping () -> Void
	) -> some View {
		alert(title, isPresented: isPresented) {
			Button("Delete", role: .destructive, action: onDelete)
			Button("Cancel", role: .cancel) { }
		} message: {
			Text(message)
		}
	}
}
