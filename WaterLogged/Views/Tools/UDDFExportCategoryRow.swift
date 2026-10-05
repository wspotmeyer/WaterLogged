//
//  UDDFExportCategoryRow.swift
//  WaterLogged
//
//  Created by John Meyer on 8/15/26.
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

/// A single switchable row in the UDDF export tool: the category's name and
/// item count, toggling its membership in the export selection.
struct UDDFExportCategoryRow: View {
	let category: UDDFExportCategory
	let count: Int
	@Binding var selection: UDDFExportSelection

	private var isIncluded: Binding<Bool> {
		Binding(
			get: { selection.contains(category) },
			set: { isOn in
				if isOn {
					selection.insert(category)
				} else {
					selection.remove(category)
				}
			}
		)
	}

	var body: some View {
		Toggle(isOn: isIncluded) {
			HStack {
				Label {
					Text(category.title)
				} icon: {
					Image(systemName: category.systemImage)
				}
				Spacer(minLength: 0)
				Text(count, format: .number)
					.monospacedDigit()
					.foregroundStyle(.secondary)
			}
		}
		.accessibilityValue(Text("\(count) items"))
	}
}

#Preview {
	@Previewable @State var selection = UDDFExportSelection.all

	Form {
		ForEach(UDDFExportCategory.allCases) { category in
			UDDFExportCategoryRow(category: category, count: 12, selection: $selection)
		}
	}
	.appFormStyle()
}
