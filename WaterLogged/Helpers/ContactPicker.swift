//
//  ContactPicker.swift
//  WaterLogged
//
//  Created by John Meyer on 2/23/26.
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
import Contacts

#if canImport(UIKit)
import ContactsUI

struct ContactPicker: UIViewControllerRepresentable {
	let onSelect: (CNContact) -> Void

	func makeCoordinator() -> Coordinator {
		Coordinator(onSelect: onSelect)
	}

	func makeUIViewController(context: Context) -> CNContactPickerViewController {
		let picker = CNContactPickerViewController()
		picker.delegate = context.coordinator
		return picker
	}

	func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

	class Coordinator: NSObject, CNContactPickerDelegate {
		let onSelect: (CNContact) -> Void

		init(onSelect: @escaping (CNContact) -> Void) {
			self.onSelect = onSelect
		}

		func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
			onSelect(contact)
		}
	}
}

#elseif canImport(AppKit)
import ContactsUI

struct ContactPickerAnchor: NSViewRepresentable {
	@Binding var isPresented: Bool
	let onSelect: (CNContact) -> Void

	func makeCoordinator() -> Coordinator {
		Coordinator(onSelect: onSelect)
	}

	func makeNSView(context: Context) -> NSView {
		let view = NSView()
		context.coordinator.anchorView = view
		return view
	}

	func updateNSView(_ nsView: NSView, context: Context) {
		if isPresented && !context.coordinator.isShowing {
			context.coordinator.show { [self] in
				isPresented = false
			}
		}
	}

	class Coordinator: NSObject, CNContactPickerDelegate {
		let onSelect: (CNContact) -> Void
		var anchorView: NSView?
		var isShowing = false
		private var picker: CNContactPicker?
		private var onDismiss: (() -> Void)?

		init(onSelect: @escaping (CNContact) -> Void) {
			self.onSelect = onSelect
		}

		func show(onDismiss: @escaping () -> Void) {
			guard let anchorView else { return }
			isShowing = true
			self.onDismiss = onDismiss
			let picker = CNContactPicker()
			picker.delegate = self
			self.picker = picker
			picker.showRelative(to: anchorView.bounds, of: anchorView, preferredEdge: .maxY)
		}

		func contactPicker(_ picker: CNContactPicker, didSelect contact: CNContact) {
			onSelect(contact)
			cleanup()
		}

		func contactPickerDidClose(_ picker: CNContactPicker) {
			cleanup()
		}

		private func cleanup() {
			isShowing = false
			picker = nil
			onDismiss?()
			onDismiss = nil
		}
	}
}
#endif
