//
//  ContentView.swift
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
import SwiftData
#if os(macOS)
import UniformTypeIdentifiers
#endif

/// Hosts the app's root navigation (`AdaptiveRootView`) along with
/// window-level concerns: the shared map state and, on macOS, the sheets and
/// importers driven by the File menu's `NewItemIntent`.
struct ContentView: View {
	@State private var mapState = SharedMapState()
#if os(macOS)
	@Environment(NewItemIntent.self) private var newItemIntent
	@Environment(\.modelContext) private var modelContext
	@State private var uddfImportResult: UDDFImportResult?
#endif

	var body: some View {
#if os(macOS)
		@Bindable var intent = newItemIntent
#endif
		AdaptiveRootView()
			.appGradient()
			.environment(mapState)
#if os(macOS)
			.sheet(item: $intent.pending) { kind in
				Group {
					switch kind {
						case .dive: DiveEntryView(dive: nil)
						case .diveSite: DiveSiteEntryView(site: nil)
						case .trip: TripEntryView(trip: nil)
						case .buddy: BuddyEntryView(buddy: nil)
						case .equipment: EquipmentEntryView(equipment: nil)
						case .gasMix: GasMixEntryView(gasMix: nil)
					}
				}
				.frame(minWidth: 700)
			}
			.sheet(isPresented: $intent.showingDiveComputerImport) {
				DiveComputerView()
					.frame(minWidth: 700)
			}
			.sheet(isPresented: $intent.showingBulkUpdater) {
				BulkUpdateView(presentation: .sheet)
					.frame(minWidth: 700)
			}
			.sheet(isPresented: $intent.showingBackup) {
				BackupToolView(presentation: .sheet)
					.frame(minWidth: 700)
			}
			.sheet(isPresented: $intent.showingRestore) {
				RestoreToolView(presentation: .sheet)
					.frame(minWidth: 700)
			}
			.fileImporter(
				isPresented: $intent.showingUDDFImport,
				allowedContentTypes: [.uddf, .xml]
			) { result in
				switch result {
					case .success(let url):
						do {
							let summary = try UDDFImporter.importFile(at: url, into: modelContext)
							uddfImportResult = .success(summary)
						} catch {
							uddfImportResult = .failure(error.localizedDescription)
						}
					case .failure(let error):
						uddfImportResult = .failure(error.localizedDescription)
				}
			}
			.alert(uddfImportResult?.title ?? "", item: $uddfImportResult) { _ in
				Button("OK") { }
			} message: { result in
				Text(result.message)
			}
#endif
	}
}

#Preview {
	ContentView()
		.modelContainer(PreviewContainer.container)
#if os(macOS)
		.environment(NewItemIntent())
#endif
}
