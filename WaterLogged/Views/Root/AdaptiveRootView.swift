//
//  AdaptiveRootView.swift
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

/// The app's root navigation: a `TabView` hosting every top-level
/// destination.
///
/// Rendering per platform: iPad shows a top tab bar that morphs into a
/// sidebar; iPhone shows a bottom tab bar; macOS shows the default tab strip
/// (see the `#if !os(macOS)` note on the style modifier below). Record-type
/// tabs host two-column `NavigationSplitView` list views, so with the
/// sidebar visible the app reads as three panes: sections, list, detail.
/// Sections with no list/detail (Map, Stats, Tools, Settings, About)
/// simply fill the content area.
///
/// Sidebar order follows the builder for `TabSection`s, but tabs declared
/// outside a section are collected into one implicit group at the top of the
/// sidebar regardless of where they appear in the builder. Only Map and
/// Browse are meant to sit there, so the utility destinations are wrapped in
/// a "More" `TabSection` to keep them below Log Book, Gear, and People.
///
/// In compact width (or iPhone landscape; see `isCompact`) only Map, Dives,
/// Dive Sites, Trips, and Browse fit the tab bar; the remaining destinations
/// are hidden tabs reachable through `BrowseView`. Selecting a hidden tab
/// programmatically crashes (UIKit's tab model only contains visible tabs),
/// so `open(_:)` first REVEALS the target tab — via `revealedTab` feeding
/// each tab's `hidden(_:)` condition — and then selects it in the same update.
struct AdaptiveRootView: View {
	@State private var selection: RootTab = .home

	/// The one normally-hidden tab currently allowed in the compact tab bar,
	/// chosen from Browse or a deep link. Irrelevant in regular width, where
	/// no tab is hidden.
	@State private var revealedTab: RootTab?
#if !os(macOS)
	@Environment(\.horizontalSizeClass) private var horizontalSizeClass
	@Environment(\.verticalSizeClass) private var verticalSizeClass
#endif

	/// Whether the tab bar is limited to the five-item compact layout.
	/// Vertically compact counts too: a large iPhone in landscape is
	/// horizontally regular, but `.sidebarAdaptable` still shows iPhone's
	/// bottom tab bar there (no sidebar), so showing every tab would overflow
	/// it into UIKit's "More" tab.
	private var isCompact: Bool {
#if os(macOS)
		false
#else
		horizontalSizeClass == .compact || verticalSizeClass == .compact
#endif
	}

	/// Whether `tab` is one of the destinations that doesn't fit the compact
	/// tab bar and is reachable through Browse instead.
	private func fitsCompactBarOnlyViaBrowse(_ tab: RootTab) -> Bool {
		switch tab {
			case .home, .dives, .diveSites, .trips, .browse: false
			default: true
		}
	}

	/// The tab revealed in the current render. Derived from `selection` first
	/// so the selected tab is never hidden: a size-class change re-renders
	/// with the new width BEFORE `onChange(of: isCompact)` can update
	/// `revealedTab`, and a hidden selection in that render crashes.
	private var effectiveRevealedTab: RootTab? {
		switch selection {
			case .trips: nil
			case let tab where fitsCompactBarOnlyViaBrowse(tab): tab
			default: revealedTab
		}
	}

	private func isHidden(_ tab: RootTab) -> Bool {
		guard isCompact else { return false }
		// A revealed tab takes Trips' slot so the compact bar stays at
		// five items; a sixth would push Browse into a UIKit "More" tab.
		if tab == .trips {
			return effectiveRevealedTab != nil
		}
		return effectiveRevealedTab != tab
	}

	/// The selection handed to the `TabView`. Browse only exists in compact
	/// width, so when the width turns regular (e.g. widening an iPad window)
	/// the render that hides Browse must already select another
	/// tab; waiting for `onChange(of: isCompact)` is one update too late.
	private var tabSelection: Binding<RootTab> {
		Binding {
			selection == .browse && !isCompact ? .home : selection
		} set: { newValue in
			selection = newValue
		}
	}

	/// Switches to `tab`, first revealing it if it's hidden in the current
	/// width. Reveal and selection land in the same update, so the tab is
	/// back in the tab bar's model before it becomes the selection.
	private func open(_ tab: RootTab) {
		if isCompact {
			revealedTab = fitsCompactBarOnlyViaBrowse(tab) ? tab : nil
		}
		selection = tab
	}

	var body: some View {
		TabView(selection: tabSelection) {
			Tab("Map", systemImage: "globe.desk.fill", value: RootTab.home) {
				HomeMapView()
			}

			TabSection("Log Book") {
				Tab("Dives", systemImage: "water.waves.and.arrow.trianglehead.down", value: RootTab.dives) {
					DiveListView()
				}
				Tab("Dive Sites", systemImage: "mappin.and.ellipse", value: RootTab.diveSites) {
					DiveSiteListView()
				}
				Tab("Trips", systemImage: "airplane.path.dotted", value: RootTab.trips) {
					TripListView()
				}
				.hidden(isHidden(.trips))
			}

			TabSection("Gear") {
				Tab("Equipment", systemImage: "briefcase", value: RootTab.equipment) {
					EquipmentListView()
				}
				.hidden(isHidden(.equipment))
				Tab("Gases", systemImage: "aqi.medium", value: RootTab.gasMixes) {
					GasMixListView()
				}
				.hidden(isHidden(.gasMixes))
			}

			TabSection("People") {
				Tab("Buddies", systemImage: "person.2", value: RootTab.buddies) {
					BuddyListView()
				}
				.hidden(isHidden(.buddies))
				Tab("Owner", systemImage: "person.text.rectangle", value: RootTab.owner) {
					LogbookOwnerDetailView()
				}
				.hidden(isHidden(.owner))
			}

			// Grouped only so these land after the named sections in the
			// sidebar (see the ordering note on the type).
			TabSection("More") {
				Tab("Tools", systemImage: "wrench.and.screwdriver", value: RootTab.tools) {
					ToolsView()
				}
				.hidden(isHidden(.tools))

				Tab("Dive Stats", systemImage: "chart.bar.xaxis", value: RootTab.stats) {
					StatsView()
				}
				.hidden(isHidden(.stats))

#if !os(macOS)
				Tab("Settings", systemImage: "gearshape", value: RootTab.settings) {
					SettingsView()
				}
				.hidden(isHidden(.settings))

				Tab("About", systemImage: "info.circle", value: RootTab.about) {
					AboutView()
				}
				.hidden(isHidden(.about))
#endif
			}

#if !os(macOS)
			Tab("Browse", systemImage: "square.grid.2x2", value: RootTab.browse) {
				BrowseView(openTab: open)
			}
			.hidden(!isCompact)
#endif
		}
#if !os(macOS)
		// Not applied on macOS: a NavigationSplitView nested in a
		// sidebar-adaptable TabView offsets its detail column by the tab
		// sidebar's width there (macOS 26.5). The default style's sidebar
		// does not have this problem.
		.tabViewStyle(.sidebarAdaptable)
#endif
		.onChange(of: NavigationRouter.shared.pending, initial: true) { _, pending in
			// A Spotlight deep link asks for a record; switch to its tab. The
			// destination list view then selects the record and clears the
			// pending destination (same contract as the home-page mode).
			if let pending {
				open(pending.rootTab)
			}
		}
		.onOpenURL { url in
			// A home-screen widget tap opens `waterlogged://stats`.
			if url.host == "stats" {
				open(.stats)
			}
		}
		.onChange(of: isCompact, initial: true) { _, isCompact in
			// Keep the stored state in step with width changes (Apple's
			// BrowseTabExample pattern): entering compact while on a tab that
			// doesn't fit the compact bar keeps it revealed; leaving compact
			// while on Browse (which only exists in compact) moves off it.
			// This runs after the first render at the new width, which
			// `effectiveRevealedTab` and `tabSelection` already keep valid.
			if isCompact {
				revealedTab = fitsCompactBarOnlyViaBrowse(selection) ? selection : nil
			} else if selection == .browse {
				selection = .home
			}
		}
	}
}

#Preview {
	AdaptiveRootView()
		.environment(SharedMapState())
		.modelContainer(PreviewContainer.container)
#if os(macOS)
		.environment(NewItemIntent())
#endif
}
