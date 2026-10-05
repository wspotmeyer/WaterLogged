//
//  UDDFExportToolView.swift
//  WaterLogged
//
//  Created by John Meyer on 7/25/26.
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
import UniformTypeIdentifiers

/// A UDDF file containing the selected logbook data, wrapped for sharing.
struct ShareableUDDFExport: Transferable {
	let url: URL

	static var transferRepresentation: some TransferRepresentation {
		FileRepresentation(exportedContentType: .uddf) { item in
			SentTransferredFile(item.url)
		}
	}
}

/// Exports a chosen selection of logbook data — dives, sites, buddies,
/// equipment and so on — to a UDDF file, then lets the user share it
/// (iOS/iPadOS) or save it via the file exporter (macOS).
struct UDDFExportToolView: View {
	/// How this view is being presented. Drives whether it shows a Home button
	/// (embedded in the Tools tab) or a Cancel button (sheet).
	enum Presentation {
		case embedded
		case sheet
	}

	var presentation: Presentation = .embedded

	@Environment(\.modelContext) private var modelContext
	@Environment(\.dismiss) private var dismiss

	@Query private var dives: [Dive]
	@Query private var sites: [DiveSite]
	@Query private var gases: [GasMix]
	@Query private var buddies: [Buddy]
	@Query private var equipment: [Equipment]
	@Query private var certifications: [Certification]
	@Query private var trips: [Trip]
	@Query private var owners: [LogbookOwner]

	@State private var selection = UDDFExportSelection.all
	@State private var isExporting = false
	@State private var exportedFile: ShareableUDDFExport?
	@State private var errorMessage: String?
#if os(macOS)
	@State private var isPresentingSavePanel = false
#endif

	private var counts: UDDFExportCounts {
		UDDFExportCounts(
			dives: dives.count,
			diveSites: sites.count,
			gasMixes: gases.count,
			buddies: buddies.count,
			equipment: equipment.count,
			certifications: certifications.count,
			trips: trips.count,
			diverProfile: owners.contains(where: \.hasPersonalDetails) ? 1 : 0
		)
	}

	private var canExport: Bool {
		counts.hasContent(for: selection)
	}

	var body: some View {
		NavigationStack {
			Form {
				Group {
					Section {
						ForEach(UDDFExportCategory.allCases) { category in
							UDDFExportCategoryRow(
								category: category,
								count: counts[category],
								selection: $selection
							)
						}

						Button(selection == .all ? "Deselect All" : "Select All") {
							selection = selection == .all ? [] : .all
						}
						.frame(maxWidth: .infinity)
					} header: {
						Text("Items to Export")
					} footer: {
						Text("Creates a UDDF file that can be imported into WaterLogged or another dive logging app. "
							 + "Excluded data is left out entirely, along with any references to it — a dive whose site "
							 + "isn't exported keeps everything except its link to that site, for example.")
					}
					.alignmentGuide(.listRowSeparatorLeading) { _ in 0 }

					Section {
						Button("Export to UDDF") {
							performExport()
						}
						.disabled(isExporting || !canExport)
						.frame(maxWidth: .infinity)

						if isExporting {
							ProgressView("Generating file…")
								.frame(maxWidth: .infinity)
						}

						if let exportedFile {
#if os(macOS)
							Button("Save UDDF File…", systemImage: "square.and.arrow.down") {
								isPresentingSavePanel = true
							}
							.frame(maxWidth: .infinity)
#else
							ShareLink(
								item: exportedFile,
								preview: SharePreview(exportedFile.url.deletingPathExtension().lastPathComponent)
							) {
								Label("Share UDDF File", systemImage: "square.and.arrow.up")
							}
							.frame(maxWidth: .infinity)
#endif
						}

						if let errorMessage {
							Label(errorMessage, systemImage: "exclamationmark.triangle")
								.foregroundStyle(.red)
						}
					} footer: {
						if !canExport {
							Text("Select at least one category that contains data.")
						}
					}
					.alignmentGuide(.listRowSeparatorLeading) { _ in 0 }

					UDDFOmittedDataSection()
						.alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
				}
				.tileListRowBackground()
			}
			.appFormStyle()
			.frame(maxWidth: 500)
			.frame(maxWidth: .infinity)
			.appGradientScrollBackground()
			.navigationTitle("Export to UDDF")
#if !os(macOS)
			.navigationBarTitleDisplayMode(.inline)
#endif
#if os(macOS)
			.fileExporter(
				isPresented: $isPresentingSavePanel,
				document: exportedFile.map { ExportedFileDocument(url: $0.url) },
				contentType: .uddf,
				defaultFilename: exportedFile?.url.deletingPathExtension().lastPathComponent
			) { result in
				if case .failure(let error) = result {
					errorMessage = error.localizedDescription
				}
			}
#endif
			.onChange(of: selection) {
				// The generated file no longer matches what's selected.
				cleanupExport()
			}
			.onDisappear {
				cleanupExport()
			}
			.toolbar {
				if presentation == .sheet {
					ToolbarItem(placement: .cancellationAction) {
						Button("Cancel", systemImage: "xmark") { dismiss() }
					}
				}
			}
		}
	}

	private func cleanupExport() {
		if let url = exportedFile?.url {
			try? FileManager.default.removeItem(at: url)
		}
		exportedFile = nil
		errorMessage = nil
	}

	private func performExport() {
		isExporting = true
		errorMessage = nil
		exportedFile = nil

		Task {
			do {
				let url = URL.temporaryDirectory
					.appending(path: selection.suggestedFileName)
					.appendingPathExtension("uddf")
				try? FileManager.default.removeItem(at: url)
				try UDDFExporter.export(from: modelContext, selecting: selection, to: url)
				exportedFile = ShareableUDDFExport(url: url)
			} catch {
				errorMessage = error.localizedDescription
			}
			isExporting = false
		}
	}
}

#Preview {
	UDDFExportToolView()
		.modelContainer(PreviewContainer.container)
}
