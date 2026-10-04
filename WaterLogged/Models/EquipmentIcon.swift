//
//  EquipmentIcon.swift
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

import DeveloperToolsSupport

/// The source of an equipment type's icon, allowing SF Symbols and custom asset-catalog
/// artwork to be mixed freely across `EquipmentType` cases.
///
/// `ImageResource` is used rather than a bare asset name so that a typo or a
/// not-yet-drawn icon is a compile error instead of a silently blank image.
///
/// Render these with `EquipmentTypeIcon` or `EquipmentTypeLabel` rather than branching
/// at each call site — custom artwork needs font-relative sizing that SF Symbols get for
/// free, and those views handle the difference.
enum EquipmentIcon: Hashable, Sendable {
	/// An SF Symbol, referenced by its system name.
	case system(String)

	/// A custom vector image in the app's asset catalog.
	case custom(ImageResource)
}
