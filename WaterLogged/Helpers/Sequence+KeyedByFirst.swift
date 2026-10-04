//
//  Sequence+KeyedByFirst.swift
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

import Foundation

nonisolated extension Sequence {
	/// A lookup table from `key` to element. When several elements share a key,
	/// the first one wins — later duplicates are ignored, never merged.
	func keyedByFirst<Key: Hashable>(_ key: (Element) -> Key) -> [Key: Element] {
		Dictionary(map { (key($0), $0) }, uniquingKeysWith: { first, _ in first })
	}
}
