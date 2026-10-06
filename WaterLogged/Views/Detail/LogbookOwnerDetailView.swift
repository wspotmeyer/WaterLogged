//
//  LogbookOwnerDetailView.swift
//  WaterLogged
//
//  Created by John Meyer on 4/25/26.
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

struct LogbookOwnerDetailView: View {
	@Environment(\.modelContext) private var modelContext
	@Query(sort: \Certification.dateAchieved) private var certifications: [Certification]

	@State private var owner: LogbookOwner?
	@State private var editingOwner: LogbookOwner?

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: 24) {
					if let owner, owner.isLive {
						OwnerPhotoHeader(owner: owner)

						if hasOwnerInfo(owner) {
							OwnerInfoHeader(owner: owner)
						}

						if hasContactInfo(owner) {
							OwnerContactSection(owner: owner)
						}

						if hasAddress(owner) {
							OwnerAddressSection(owner: owner)
						}
					}

					OwnerCertificationsSection(certifications: certifications)
				}
				.padding()
				.frame(maxWidth: 700)
				.frame(maxWidth: .infinity)
			}
			.appGradientScrollBackground()
			.navigationTitle("Owner")
#if !os(macOS)
			.navigationBarTitleDisplayMode(.inline)
#endif
			.toolbar {
				ToolbarItem(placement: .primaryAction) {
					Button("Edit", systemImage: "pencil") {
						editingOwner = owner
					}
				}
			}
			.onAppear {
				owner = try? LogbookOwner.fetchOrCreate(in: modelContext)
				linkOrphanedCertifications()
			}
			.sheet(item: $editingOwner) { _ in
				LogbookOwnerEntryView()
			}
		}
	}

	/// Links any certifications that have no owner to the current owner.
	private func linkOrphanedCertifications() {
		guard let owner else { return }
		for cert in certifications where cert.owner == nil {
			cert.owner = owner
		}
	}

	private func hasOwnerInfo(_ owner: LogbookOwner) -> Bool {
		!owner.givenName.isEmpty || !owner.familyName.isEmpty
	}

	private func hasContactInfo(_ owner: LogbookOwner) -> Bool {
		!owner.telephone.isEmpty || !owner.email.isEmpty || !owner.webPage.isEmpty
	}

	private func hasAddress(_ owner: LogbookOwner) -> Bool {
		!owner.street.isEmpty || !owner.city.isEmpty || !owner.state.isEmpty
		|| !owner.province.isEmpty || !owner.postalCode.isEmpty || !owner.country.isEmpty
	}
}

// MARK: - Photo Header

private struct OwnerPhotoHeader: View {
	let owner: LogbookOwner

	var body: some View {
		HStack {
			Spacer()
			BuddyPhoto(photoData: owner.photoData, size: 120)
			Spacer()
		}
	}
}

// MARK: - Info Header

private struct OwnerInfoHeader: View {
	let owner: LogbookOwner

	var body: some View {
		if !owner.formattedName.isEmpty {
			Text(owner.formattedName)
				.font(.title.bold())
		}
	}
}

// MARK: - Contact Section

private struct OwnerContactSection: View {
	let owner: LogbookOwner

	var body: some View {
		DetailSection(title: "Contact Information") {
			if !owner.telephone.isEmpty {
				DetailRow(label: "Telephone", value: owner.telephone)
			}
			if !owner.email.isEmpty {
				DetailRow(label: "Email", value: owner.email)
			}
			if !owner.webPage.isEmpty {
				DetailRow(label: "Web Page", value: owner.webPage)
			}
		}
	}
}

// MARK: - Address Section

private struct OwnerAddressSection: View {
	let owner: LogbookOwner

	private var cityStateLine: String {
		var parts: [String] = []
		if !owner.city.isEmpty { parts.append(owner.city) }
		let region = !owner.state.isEmpty ? owner.state : owner.province
		if !region.isEmpty { parts.append(region) }
		var line = parts.joined(separator: ", ")
		if !owner.postalCode.isEmpty {
			if !line.isEmpty { line += " " }
			line += owner.postalCode
		}
		return line
	}

	var body: some View {
		DetailSection(title: "Address") {
			VStack(alignment: .leading, spacing: 4) {
				if !owner.street.isEmpty {
					Text(owner.street)
				}
				if !cityStateLine.isEmpty {
					Text(cityStateLine)
				}
				if !owner.province.isEmpty && !owner.state.isEmpty {
					Text("Province: \(owner.province)")
				}
				if !owner.country.isEmpty {
					Text(owner.country)
				}
			}
		}
	}
}

// MARK: - Certifications Section

private struct OwnerCertificationsSection: View {
	let certifications: [Certification]

	var body: some View {
		if !certifications.isEmpty {
			GroupBox {
				VStack(spacing: 0) {
					ForEach(certifications) { cert in
						NavigationLink {
							CertificationDetailView(certification: cert)
						} label: {
							HStack {
								Text(cert.name)
									.lineLimit(1)
								Spacer()
								if let date = cert.dateAchieved {
									Text(date.formatted(date: .abbreviated, time: .omitted))
										.foregroundStyle(.secondary)
										.lineLimit(1)
								}
								Image(systemName: "chevron.right")
									.font(.caption)
							}
							.padding(.top, 12)
						}
						.buttonStyle(.plain)
					}
				}
				.frame(maxWidth: .infinity, alignment: .leading)
			} label: {
				HStack {
					Text("Certifications")
						.font(.title2.bold())
					Spacer()
					CountCapsule(text: "\(certifications.count)", color: .gray, font: .headline)
				}
			}
			.tileBackgroundStyle()
		}
	}
}

#Preview {
	LogbookOwnerDetailView()
		.environment(SharedMapState())
		.modelContainer(PreviewContainer.container)
}
