//
//  BackupToolView.swift
//  WaterLogged
//
//  Created by John Meyer on 4/24/26.
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

struct ShareableExport: Transferable {
	let url: URL

	static var transferRepresentation: some TransferRepresentation {
		FileRepresentation(exportedContentType: .zip) { item in
			SentTransferredFile(item.url)
		}
	}
}

struct BackupToolView: View {
	/// How `BackupToolView` is being presented. Drives whether it shows a Home
	/// button (embedded in the Tools tab) or a Cancel button (sheet).
	enum Presentation {
		case embedded
		case sheet
	}

	var presentation: Presentation = .embedded

	@Environment(\.modelContext) private var modelContext
	@Environment(\.dismiss) private var dismiss

	@Query(sort: \Dive.date) private var dives: [Dive]
	@Query private var sites: [DiveSite]
	@Query private var gases: [GasMix]
	@Query private var buddies: [Buddy]
	@Query private var equipment: [Equipment]
	@Query private var certifications: [Certification]
	@Query private var trips: [Trip]

	@State private var isExporting = false
	@State private var exportedFile: ShareableExport?
	@State private var errorMessage: String?
#if os(macOS)
	@State private var isPresentingSavePanel = false
#endif

	private var hasData: Bool {
		!dives.isEmpty || !equipment.isEmpty || !certifications.isEmpty
	}

	var body: some View {
		NavigationStack {
			Form {
				Group {
					Section {
						LabeledContent("Dives", value: "\(dives.count)")
						LabeledContent("Dive Sites", value: "\(sites.count)")
						LabeledContent("Gas Mixes", value: "\(gases.count)")
						LabeledContent("Buddies", value: "\(buddies.count)")
						LabeledContent("Equipment", value: "\(equipment.count)")
						LabeledContent("Certifications", value: "\(certifications.count)")
						LabeledContent("Trips", value: "\(trips.count)")
					} header: {
						Text("Backup Summary")
					} footer: {
						Text("Backs up your complete log book as a ZIP archive containing a UDDF file, supplementary data, and media.")
					}

					Section {
						Button("Back Up Log Book") {
							performExport()
						}
						.disabled(isExporting || !hasData)
						.frame(maxWidth: .infinity)

						if isExporting {
							ProgressView("Generating backup…")
								.frame(maxWidth: .infinity)
						}

						if let exportedFile {
#if os(macOS)
							Button("Save Backup…", systemImage: "square.and.arrow.down") {
								isPresentingSavePanel = true
							}
							.frame(maxWidth: .infinity)
#else
							ShareLink(
								item: exportedFile,
								preview: SharePreview("WaterLogged Backup")
							) {
								Label("Save Backup", systemImage: "square.and.arrow.up")
							}
							.frame(maxWidth: .infinity)
#endif
						}

						if let errorMessage {
							Label(errorMessage, systemImage: "exclamationmark.triangle")
								.foregroundStyle(.red)
						}
					}
					.alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
				}
				.tileListRowBackground()
			}
			.appFormStyle()
			.frame(maxWidth: 500)
			.frame(maxWidth: .infinity)
			.appGradientScrollBackground()
			.navigationTitle("Backup")
#if !os(macOS)
			.navigationBarTitleDisplayMode(.inline)
#endif
#if os(macOS)
			.fileExporter(
				isPresented: $isPresentingSavePanel,
				document: exportedFile.map { ExportedFileDocument(url: $0.url) },
				contentType: .zip,
				defaultFilename: exportedFile?.url.deletingPathExtension().lastPathComponent
			) { result in
				if case .failure(let error) = result {
					errorMessage = error.localizedDescription
				}
			}
#endif
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
		exportedFile = nil
		let fm = FileManager.default
		let tmpDir = URL.temporaryDirectory
		guard let contents = try? fm.contentsOfDirectory(at: tmpDir, includingPropertiesForKeys: nil) else { return }
		for file in contents where file.lastPathComponent.hasPrefix("WaterLogged_") && file.pathExtension == "zip" {
			try? fm.removeItem(at: file)
		}
	}

	private func performExport() {
		isExporting = true
		errorMessage = nil
		exportedFile = nil

		Task {
			do {
				let url = try BackupPackager.createExportArchive(from: modelContext)
				exportedFile = ShareableExport(url: url)
			} catch {
				errorMessage = error.localizedDescription
			}
			isExporting = false
		}
	}
}

#Preview {
	BackupToolView()
}
