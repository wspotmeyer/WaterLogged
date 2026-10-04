//
//  DiveTransferView.swift
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

struct DiveTransferView: View {
	let progress: TransferProgress

	var body: some View {
		VStack(spacing: 20) {
			Spacer()

			Image(systemName: "arrow.down.circle")
				.font(.system(size: 48))
				.foregroundStyle(.tint)
				.symbolEffect(.pulse)

			Text("Downloading Dives")
				.font(.title2)
				.bold()

			Text(statusText)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
				.contentTransition(.numericText())

			if let fraction = progressFraction {
				VStack {
					ProgressView(value: fraction)
					Text(fraction, format: .percent.precision(.fractionLength(0)))
						.multilineTextAlignment(.center)
				}
				.padding(.horizontal, 40)
			} else {
				ProgressView()
			}

			Spacer()
		}
		.frame(maxWidth: .infinity)
		.animation(.default, value: statusText)
	}

	private var statusText: String {
		switch progress {
			case .connecting:
				"Establishing connection…"
			case .discoveringServices:
				"Discovering services…"
			case .handshaking:
				"Handshaking with device…"
			case .transferring:
				"Downloading dive data…"
			case .parsingDive(let current, let total):
				"Parsing dive \(current) of \(total)…"
			case .complete(let count):
				"Downloaded \(count) dive\(count == 1 ? "" : "s")"
		}
	}

	/// Normalized 0–1 progress fraction, or nil for an indeterminate state.
	private var progressFraction: Double? {
		switch progress {
			case .transferring(let received, let total) where total > 0:
				Double(received) / Double(total)
			case .parsingDive(let current, let total) where total > 0:
				Double(current) / Double(total)
			default:
				nil
		}
	}
}
