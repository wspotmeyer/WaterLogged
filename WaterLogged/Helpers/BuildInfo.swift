//
//  BuildInfo.swift
//  WaterLogged
//
//  Created by John Meyer on 10/10/26.
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

/// The Git commit a binary was built from, for display next to the build number.
///
/// The commit comes from `BuildCommit.txt`, a generated (never committed) resource that
/// `Scripts/write-build-commit.sh` writes — via git hooks for local builds and
/// `ci_scripts/ci_post_clone.sh` in Xcode Cloud. A fresh clone without the hooks has no
/// such file, in which case only the build number is shown.
enum BuildInfo {

	/// The bundled resource holding the short commit hash.
	static let commitResourceName = "BuildCommit"

	/// The short commit hash bundled with the app, or `nil` if it wasn't recorded.
	static func commit(in bundle: Bundle = .main) -> String? {
		guard let url = bundle.url(forResource: commitResourceName, withExtension: "txt"),
			  let contents = try? String(contentsOf: url, encoding: .utf8) else {
			return nil
		}
		return commit(fromFileContents: contents)
	}

	/// Extracts a commit hash from the file's contents, rejecting anything that
	/// isn't 7–40 hexadecimal digits so a damaged file never reaches the UI.
	static func commit(fromFileContents contents: String) -> String? {
		let hash = contents.trimmingCharacters(in: .whitespacesAndNewlines)
		guard (7...40).contains(hash.count), hash.allSatisfy(\.isHexDigit) else {
			return nil
		}
		return hash.lowercased()
	}

	/// The About screen's build line: "(42) d3fa839", or just "42" without a commit.
	static func buildDescription(buildNumber: String, commit: String?) -> String {
		guard let commit else { return buildNumber }
		return "(\(buildNumber)) \(commit)"
	}
}
