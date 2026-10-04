//
//  HomeMapView.swift
//  WaterLogged
//
//  Created by John Meyer on 7/2/26.
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
import SwiftData

/// The Home tab: the all-sites map with the mini statistics (or welcome)
/// overlay. The tab bar or sidebar provides navigation, so the map fills
/// the screen.
struct HomeMapView: View {
	@Query var dives: [Dive]
	@State private var isMinimized = false

	var body: some View {
		AllSitesMapView()
			.overlay(alignment: .bottom) {
				if isMinimized {
					// Restore button centered at the bottom
					Button(action: { withAnimation { isMinimized = false } }) {
						Image(systemName: "chevron.up.2")
							.font(.subheadline.bold())
							.padding(8)
							.background(.fill.tertiary, in: .circle)
							.foregroundStyle(.white)
							.glassEffect(.clear, in: .circle)
							.phaseAnimator([false, true]) { content, phase in
								content.opacity(phase ? 0.1 : 1.0)
							} animation: { _ in
									.easeInOut(duration: 1.5)
							}
							.padding(8)
							.contentShape(.circle)
					}
					.buttonStyle(.plain)
					.padding(.bottom)
					.transition(.move(edge: .bottom).combined(with: .opacity))
				} else {
					StatsBarPanel(hasDives: !dives.isEmpty) {
						withAnimation { isMinimized = true }
					}
					.padding(.bottom)
					.transition(.opacity.combined(with: .scale(scale: 0.9)))
				}
			}
		// Collapsing the stats bar also hides the tab bar for a truly
		// full-screen map; restoring brings it back. Visibility flows up to
		// the enclosing TabView. Not applied on macOS, where the tab strip
		// is the primary navigation chrome.
#if !os(macOS)
			.toolbar(isMinimized ? .hidden : .automatic, for: .tabBar)
#endif
			.animation(.default, value: isMinimized)
	}
}

// MARK: - Stats Bar Panel

/// The statistics (or welcome) bar with a collapse button centered at its
/// bottom edge, protruding downward.
private struct StatsBarPanel: View {
	let hasDives: Bool
	let minimize: () -> Void

	var body: some View {
		Group {
			if hasDives {
				StatisticsBar()
			} else {
				WelcomeBar()
			}
		}
		.overlay(alignment: .bottom) {
			Button(action: minimize) {
				Image(systemName: "chevron.down.2")
					.font(.subheadline.bold())
					.padding(8)
					.background(.fill.tertiary, in: .circle)
					.foregroundStyle(.white)
					.glassEffect(.clear, in: .circle)
					.phaseAnimator([false, true]) { content, phase in
						content.opacity(phase ? 0.1 : 1.0)
					} animation: { _ in
							.easeInOut(duration: 1.5)
					}
					.padding(8)
					.contentShape(.circle)
			}
			.buttonStyle(.plain)
			.alignmentGuide(.bottom) { d in d[VerticalAlignment.center] }
		}
	}
}

#Preview {
	HomeMapView()
		.environment(SharedMapState())
		.modelContainer(PreviewContainer.container)
}
