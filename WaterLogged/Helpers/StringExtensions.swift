//
//  StringExtensions.swift
//  WaterLogged
//
//  Created by John Meyer on 5/17/26.
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

extension String {
	/// Inline Markdown punctuation removed so a value entered with formatting characters
	/// (asterisks, underscores, etc.) sorts the same as the unformatted text.
	var markdownStripped: String {
		var result = self
		result.removeAll { c in
			c == "*" || c == "_" || c == "`" || c == "~" || c == "#"
			|| c == "[" || c == "]" || c == "(" || c == ")" || c == "\\"
		}
		return result
	}
}
