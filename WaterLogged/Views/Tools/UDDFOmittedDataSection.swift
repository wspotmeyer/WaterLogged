//
//  UDDFOmittedDataSection.swift
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

/// Lists the WaterLogged-only details that a UDDF export cannot carry, so the
/// user knows to reach for the Backup tool when they need a complete copy.
struct UDDFOmittedDataSection: View {
	var body: some View {
		Section {
			ForEach(UDDFOmittedDataGroup.allCases) { group in
				VStack(alignment: .leading) {
					Text(group.title)
						.font(.subheadline)
						.bold()
					Text(group.details)
						.font(.caption)
						.foregroundStyle(.secondary)
						.fixedSize(horizontal: false, vertical: true)
				}
				.frame(maxWidth: .infinity, alignment: .leading)
			}
		} header: {
			Text("Not Included in UDDF")
		} footer: {
			Text("WaterLogged does not write these data items to a UDDF file, so they are left out no matter "
				 + "what you select above; the UDDF format has no equivalent for almost all of them. The "
				 + "records themselves are still exported — only these extra details are dropped. To save a "
				 + "complete copy of your log book, use the Backup tool instead.")
		}
	}
}

#Preview {
	Form {
		UDDFOmittedDataSection()
	}
	.formStyle(.grouped)
}
