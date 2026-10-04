//
//  CertificationDetailView.swift
//  WaterLogged
//
//  Created by John Meyer on 3/28/26.
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

struct CertificationDetailView: View {
	@Environment(\.modelContext) private var modelContext

	let certification: Certification
	var onDelete: (() -> Void)?

	@State private var editingCertification: Certification?

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 24) {

				// Header
				Text(LocalizedStringKey(certification.name))
					.font(.title.bold())

				if !certification.certificationNumber.isEmpty {
					DetailSection(title: "Certification Details") {
						DetailRow(label: "Number", value: certification.certificationNumber)
						if !certification.issuingAgency.isEmpty {
							DetailRow(label: "Agency", value: certification.issuingAgency)
						}
						if let date = certification.dateAchieved {
							DetailRow(label: "Date Achieved", value: date.formatted(date: .long, time: .omitted))
						}
					}
				}

				if hasInstructorDetails {
					DetailSection(title: "Instructor") {
						if !certification.instructorName.isEmpty {
							DetailRow(label: "Name", value: certification.instructorName)
						}
						if !certification.instructorNumber.isEmpty {
							DetailRow(label: "Number", value: certification.instructorNumber)
						}
					}
				}

				if !certification.diveShop.isEmpty {
					DetailSection(title: "Dive Shop") {
						Text(certification.diveShop)
							.font(.subheadline)
					}
				}

				// Card Images
				if certification.frontImageData != nil || certification.backImageData != nil {
					Divider()

					DetailSection(title: "Certification Card") {
						if let frontData = certification.frontImageData,
						   let frontImage = makeDisplayImage(from: frontData) {
							VStack(alignment: .leading, spacing: 4) {
								Text("Front")
									.font(.caption)
								frontImage
									.resizable()
									.scaledToFit()
									.clipShape(.rect(cornerRadius: 8))
							}
						}
						if let backData = certification.backImageData,
						   let backImage = makeDisplayImage(from: backData) {
							VStack(alignment: .leading, spacing: 4) {
								Text("Back")
									.font(.caption)
								backImage
									.resizable()
									.scaledToFit()
									.clipShape(.rect(cornerRadius: 8))
							}
						}
					}
				}

				CertificationDivesSection(certification: certification)
			}
			.padding()
			.frame(maxWidth: 700)
			.frame(maxWidth: .infinity)
		}
		.appGradientScrollBackground()
		.toolbar {
			ToolbarItem(placement: .primaryAction) {
				Button("Edit", systemImage: "pencil") {
					editingCertification = certification
				}
			}
		}
		.sheet(item: $editingCertification) { editing in
			CertificationEntryView(certification: editing, onDelete: {
				modelContext.delete(editing)
				onDelete?()
			})
		}
	}

	private var hasInstructorDetails: Bool {
		!certification.instructorName.isEmpty
		|| !certification.instructorNumber.isEmpty
	}
}

// MARK: - Dives Section

private struct CertificationDivesSection: View {
	let certification: Certification

	@State private var isExpanded = false

	var body: some View {
		if let dives = certification.dives, !dives.isEmpty {
			Divider()

			GroupBox {
				if isExpanded {
					VStack(spacing: 0) {
						ForEach(dives.sorted(by: { $0.date < $1.date })) { dive in
							DiveLinkRow(dive: dive)
						}
					}
					.frame(maxWidth: .infinity, alignment: .leading)
				}
			} label: {
				HStack {
					Text("Dives")
						.font(.title2.bold())
					Spacer()
					TimeCount(seconds: certification.totalDiveTimeSeconds, font: .headline)
					DiveCount(count: dives.count, font: .headline)
					DisclosureToggleButton(isExpanded: $isExpanded, subject: "Dives")
				}
			}
			.tileBackgroundStyle()
		}
	}
}

#Preview {
	let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
	// swiftlint:disable:next force_try
	let container = try! ModelContainer(for: Certification.self, configurations: config)
	let cert = Certification(
		name: "Open Water Diver",
		certificationNumber: "1234567890",
		dateAchieved: Calendar.current.date(from: DateComponents(year: 2024, month: 6, day: 15)),
		issuingAgency: "PADI",
		instructorName: "Jane Smith",
		instructorNumber: "INST-4567",
		diveShop: "Blue Horizon Dive Center"
	)
	container.mainContext.insert(cert)
	return NavigationStack {
		CertificationDetailView(certification: cert)
	}
	.modelContainer(container)
}
