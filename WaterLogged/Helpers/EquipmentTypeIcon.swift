//
//  EquipmentTypeIcon.swift
//  WaterLogged
//
//  Created by John Meyer on 9/5/26.
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

/// Renders an equipment type's icon, transparently handling both SF Symbols and custom
/// asset-catalog artwork.
struct EquipmentTypeIcon: View {
	let type: EquipmentType

	/// Whether the icon names the equipment type to VoiceOver. Pass `false` when the icon
	/// sits beside text that already names the type — as it does inside
	/// `EquipmentTypeLabel` — so the name isn't announced twice.
	var announcesType: Bool = true

	/// Custom artwork is a plain vector image set rather than a symbol set, so it has no
	/// intrinsic text-relative size the way an SF Symbol does. Match the height of a
	/// body-sized symbol and scale with Dynamic Type from there.
	@ScaledMetric(relativeTo: .body) private var customIconSize: CGFloat = 17

	var body: some View {
		Group {
			switch type.icon {
				case .system(let name):
					Image(systemName: name)
				case .custom(let resource):
					Image(resource)
						.resizable()
						.scaledToFit()
						.frame(width: customIconSize, height: customIconSize)
			}
		}
		// Left to itself a custom image announces its asset name, where an SF Symbol
		// carries a system-provided description. Make both branches agree.
		.accessibilityLabel(type.label)
		.accessibilityHidden(!announcesType)
	}
}

// Two columns so every type fits on one screen, for comparing the optical weight and
// alignment of newly drawn artwork against the rest of the set.
#Preview("Icon Gallery") {
	ScrollView {
		LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading),
							GridItem(.flexible(), alignment: .leading)]) {
			ForEach(EquipmentType.allCases) { type in
				EquipmentTypeLabel(type: type)
			}
		}
		.padding()
	}
}

#Preview("Icon Gallery — Accessibility Size") {
	List(EquipmentType.allCases) { type in
		EquipmentTypeLabel(type: type)
	}
	.environment(\.dynamicTypeSize, .accessibility2)
}
