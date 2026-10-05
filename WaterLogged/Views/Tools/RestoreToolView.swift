//
//  RestoreToolView.swift
//  WaterLogged
//
//  Created by John Meyer on 4/27/26.
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
#if os(macOS)
import AppKit
#endif

struct RestoreToolView: View {
	/// How `RestoreToolView` is being presented. Drives whether it shows a
	/// Home button (embedded in the Tools tab) or a Cancel button (sheet).
	enum Presentation {
		case embedded
		case sheet
	}

	var presentation: Presentation = .embedded

	@Environment(\.modelContext) private var modelContext
	@Environment(\.dismiss) private var dismiss

#if !os(macOS)
	@State private var showingFilePicker = false
#endif
	@State private var selectedURL: URL?
	@State private var showingConfirmation = false
	@State private var isRestoring = false
	@State private var resultMessage: String?
	@State private var isSuccess = false

	var body: some View {
		NavigationStack {
			Form {
				Group {
					Section {
						Text("Select a WaterLogged backup archive to restore your log book. This will replace all existing data including dives, dive sites, trips, buddies, equipment, certifications, and photos.")
					}

					Section {
						Button("Select Backup Archive…") {
							selectArchive()
						}
						.disabled(isRestoring)

						if let resultMessage {
							Label(
								resultMessage,
								systemImage: isSuccess ? "checkmark.circle" : "exclamationmark.triangle"
							)
							.foregroundStyle(isSuccess ? .green : .red)
							.frame(maxWidth: .infinity)
						}
					} footer: {
						Text("This operation cannot be undone. Make sure you have a current backup before restoring from an older one.")
					}
				}
				.tileListRowBackground()
			}
			.appFormStyle()
			.frame(maxWidth: 500)
			.frame(maxWidth: .infinity)
			.appGradientScrollBackground()
			.navigationTitle("Restore")
#if !os(macOS)
			.navigationBarTitleDisplayMode(.inline)
#endif
			.overlay {
				if isRestoring {
					VStack(spacing: 12) {
						ProgressView()
						Text("Restoring…")
							.font(.headline)
					}
					.padding()
					.background(.regularMaterial, in: .rect(cornerRadius: 12))
				}
			}
			.toolbar {
				if presentation == .sheet {
					ToolbarItem(placement: .cancellationAction) {
						Button("Cancel", systemImage: "xmark") { dismiss() }
					}
				}
			}
#if !os(macOS)
			.fileImporter(
				isPresented: $showingFilePicker,
				allowedContentTypes: [.zip]
			) { result in
				switch result {
					case .success(let url):
						selectedURL = url
						showingConfirmation = true
					case .failure(let error):
						resultMessage = error.localizedDescription
						isSuccess = false
				}
			}
#endif
			.confirmationDialog(
				"Replace All Data?",
				isPresented: $showingConfirmation,
				titleVisibility: .visible
			) {
				Button("Restore", role: .destructive) {
					performRestore()
				}
			} message: {
				Text("This will permanently replace all existing dives, equipment, certifications, and other log book data with the contents of the backup archive. All synced devices will also be updated. This cannot be undone.")
			}
		}
	}

	private func selectArchive() {
#if os(macOS)
		let panel = NSOpenPanel()
		panel.allowedContentTypes = [.zip]
		panel.allowsMultipleSelection = false
		panel.canChooseDirectories = false
		panel.canChooseFiles = true
		panel.message = "Select a WaterLogged backup archive."
		panel.prompt = "Choose"

		if panel.runModal() == .OK, let url = panel.url {
			selectedURL = url
			showingConfirmation = true
		}
#else
		showingFilePicker = true
#endif
	}

	private func performRestore() {
		guard let url = selectedURL else { return }
		isRestoring = true
		resultMessage = nil

		Task {
			// `restoreArchive` is synchronous and MainActor-isolated, so it blocks the
			// main actor for its entire duration. Yield first so SwiftUI can commit a
			// frame showing the progress overlay before the restore seizes the main
			// thread; without this the overlay is skipped on repeat restores.
			await Task.yield()
			do {
				let summary = try RestorePackager.restoreArchive(at: url, into: modelContext)
				resultMessage = summary.message
				isSuccess = true
			} catch {
				resultMessage = error.localizedDescription
				isSuccess = false
			}
			isRestoring = false
		}
	}
}

#Preview {
	RestoreToolView()
}
