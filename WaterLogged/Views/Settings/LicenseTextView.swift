//
//  LicenseTextView.swift
//  WaterLogged
//
//  Created by John Meyer on 10/9/26.
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

/// Shows the full, selectable text of a bundled license.
struct LicenseTextView: View {
	let license: LicenseDocument

	var body: some View {
		ScrollView {
			if let text = license.text() {
				Text(text)
					.font(.footnote.monospaced())
					.textSelection(.enabled)
					.frame(maxWidth: .infinity, alignment: .leading)
					.padding()
			} else {
				ContentUnavailableView("License Unavailable", systemImage: "doc.questionmark")
			}
		}
		.appGradientScrollBackground()
		.navigationTitle(license.title)
#if !os(macOS)
		.navigationBarTitleDisplayMode(.inline)
#endif
	}
}

#Preview {
	NavigationStack {
		LicenseTextView(license: .lgpl21)
	}
}
