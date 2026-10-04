//
//  AboutView.swift
//  WaterLogged
//
//  Created by John Meyer on 4/23/26.
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

struct AboutView: View {

	/// Identifies the macOS About window scene opened by `AboutCommands`.
	static let windowID = "about"

#if !os(macOS)
	@Environment(\.dismiss) private var dismiss
#endif

	private var appName: String {
		Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
		?? Bundle.main.infoDictionary?["CFBundleName"] as? String
		?? "–"
	}

	private var appVersion: String {
		Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
	}

	private var buildNumber: String {
		Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
	}

	private var libDiveComputerVersion: String {
		guard let cString = dc_version(nil) else { return "–" }
		return String(cString: cString)
	}

	private let gitHubRepo = URL(string: "https://github.com/wspotmeyer/WaterLogged")
	private let libDiveComputerSite = URL(string: "https://www.libdivecomputer.org")
	private let theNounProject = URL(string: "https://thenounproject.com")

	var body: some View {
		NavigationStack {
			Form {
				Group {
					Section {
						VStack {
							AppIconView()
							Text(appName)
								.font(.title2.bold())
							Text("Copyright © 2026 John Meyer")
								.font(.caption)
								.foregroundStyle(.secondary)
						}
						.frame(maxWidth: .infinity)
						.listRowBackground(Color.clear)
					}

					Section {
						LabeledContent("Version", value: appVersion)
						LabeledContent("Build", value: buildNumber)
						VStack(alignment: .leading) {
							Text("Source code for \(appName) is licensed under the GNU General Public License v3.")
								.foregroundStyle(.secondary)
							if let gitHubRepo {
								Link("GitHub Repository", destination: gitHubRepo)
							}
						}
						.font(.footnote)
						.frame(maxWidth: .infinity, alignment: .leading)
					}

					Section("Open Source Libraries") {
						LabeledContent("libdivecomputer", value: libDiveComputerVersion)
						VStack(alignment: .leading) {
							Group {
								Text("Dive computer communication library by Jef Driesen.")
								Text("Licensed under the GNU Lesser General Public License v2.1 or later.")
							}
							.foregroundStyle(.secondary)

							if let libDiveComputerSite {
								Link("libdivecomputer.org", destination: libDiveComputerSite)
							}
						}
						.font(.footnote)
						.frame(maxWidth: .infinity, alignment: .leading)
					}

					Section("Icons") {
						VStack(alignment: .leading) {
							Text("Diving-related icons were licensed from the Noun Project.")
								.foregroundStyle(.secondary)
							if let theNounProject {
								Link("thenounproject.com", destination: theNounProject)
							}
						}
						.font(.footnote)
						.frame(maxWidth: .infinity, alignment: .leading)
					}
				}
				.tileListRowBackground()
			}
			.formStyle(.grouped)
			.frame(maxWidth: 500)
			.frame(maxWidth: .infinity)
			.appGradientScrollBackground()
			.navigationTitle("About")
#if !os(macOS)
			.navigationBarTitleDisplayMode(.inline)
#endif
		}
	}
}

private struct AppIconView: View {
	var body: some View {
#if os(macOS)
		Image(nsImage: NSApp.applicationIconImage)
			.resizable()
			.aspectRatio(contentMode: .fit)
			.frame(width: 128, height: 128)
#else
		if let iconName = iconFileName,
		   let uiImage = UIImage(named: iconName) {
			Image(uiImage: uiImage)
				.resizable()
				.aspectRatio(contentMode: .fit)
				.frame(width: 120, height: 120)
				.clipShape(.rect(cornerRadius: 27))
		}
#endif
	}

#if !os(macOS)
	private var iconFileName: String? {
		guard let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
			  let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
			  let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String] else {
			return nil
		}
		return iconFiles.last
	}
#endif
}

#Preview {
	AboutView()
}
