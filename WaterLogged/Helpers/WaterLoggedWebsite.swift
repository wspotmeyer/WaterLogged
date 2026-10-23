//
//  WaterLoggedWebsite.swift
//  WaterLogged
//
//  Created by John Meyer on 10/23/26.
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

/// Pages on the WaterLogged website, which GitHub Pages serves from the repository's
/// `docs` folder. The support and privacy pages are also the App Store Connect support
/// and privacy policy URLs, so keep these in step with the `permalink` in each page.
enum WaterLoggedWebsite {
	static let support = URL(string: "https://wspotmeyer.github.io/WaterLogged/support/")
	static let privacyPolicy = URL(string: "https://wspotmeyer.github.io/WaterLogged/privacy/")
}
