//
//  ScubaFlagMarker.swift
//  WaterLogged
//
//  Created by John Meyer on 4/11/26.
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

/// A small red-and-white scuba diver-down flag for use as a map annotation marker.
/// When `diveCount` is greater than 1, the count is overlaid on the flag.
struct ScubaFlagMarker: View {
	var diveCount: Int = 0

	var body: some View {
		Canvas { context, size in
			// Red background
			context.fill(
				Path(CGRect(origin: .zero, size: size)),
				with: .color(.red)
			)
			// White diagonal stripe from top-left to bottom-right
			let inset: CGFloat = 1
			let topLeft = size.width * 0.25
			let bottomRight = size.width * 0.75
			var stripe = Path()
			stripe.move(to: CGPoint(x: 0, y: 0))
			stripe.addLine(to: CGPoint(x: topLeft - inset, y: 0))
			stripe.addLine(to: CGPoint(x: size.width, y: size.height - (topLeft - inset) * size.height / size.width))
			stripe.addLine(to: CGPoint(x: size.width, y: size.height))
			stripe.addLine(to: CGPoint(x: bottomRight + inset, y: size.height))
			stripe.addLine(to: CGPoint(x: 0, y: (size.width - bottomRight - inset) * size.height / size.width))
			stripe.closeSubpath()
			context.fill(stripe, with: .color(.white))
		}
		.frame(width: 30, height: 24)
		.clipShape(.rect(cornerRadius: 3))
		.shadow(radius: 2)
		.overlay {
			if diveCount > 0 {
				Text("\(diveCount)")
					.font(.system(size: 16).bold())
					.fontDesign(.rounded)
					.foregroundStyle(.black)
					.shadow(color: .white, radius: 2)
					.shadow(color: .white, radius: 4)
			}
		}
	}
}

#Preview {
	ScubaFlagMarker(diveCount: 5)
		.scaleEffect(5)
}
