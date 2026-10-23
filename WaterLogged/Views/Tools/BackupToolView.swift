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
	@State private var isPresentingSaveDialog = false
	/// Set once `fileMover` confirms the archive reached the chosen folder.
	@State private var savedBackupMessage: String?

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
								isPresentingSaveDialog = true
							}
							.frame(maxWidth: .infinity)
#else
							Button("Save to Files…", systemImage: "folder") {
								isPresentingSaveDialog = true
							}
							.frame(maxWidth: .infinity)

							// Sharing (AirDrop, Mail…) can't report completion, so
							// only the Save path above shows a confirmation.
							ShareLink(
								item: exportedFile,
								preview: SharePreview("WaterLogged Backup")
							) {
								Label("Share…", systemImage: "square.and.arrow.up")
							}
							.frame(maxWidth: .infinity)
#endif
						}

						if let savedBackupMessage {
							Label {
								Text(savedBackupMessage)
							} icon: {
								Image(systemName: "checkmark.circle.fill")
									.foregroundStyle(.green)
							}
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
			// fileMover moves the finished archive out of the temp directory and
			// only reports success once it's in the chosen folder, which is what
			// lets the sheet confirm the save (ShareLink has no completion).
			.fileMover(isPresented: $isPresentingSaveDialog, file: exportedFile?.url) { result in
				switch result {
				case .success(let url):
					backupSaved(to: url)
				case .failure(let error):
					errorMessage = error.localizedDescription
				}
			} onCancellation: {
				// Keep the temp archive so the user can save or share it again.
			}
			// fileMover's panel defaults to "Move"; to the user this is a save.
			.fileDialogConfirmationLabel("Save")
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

	private func backupSaved(to url: URL) {
		let message = FileSaveConfirmation.message(for: url)
		savedBackupMessage = message
		// The archive has moved, so there's nothing left to save or share.
		exportedFile = nil
		AccessibilityNotification.Announcement(message).post()
	}

	private func performExport() {
		isExporting = true
		errorMessage = nil
		savedBackupMessage = nil
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
