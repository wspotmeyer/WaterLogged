//
//  MacDiveSampleImporter.swift
//  WaterLogged
//
//  Created by John Meyer on 4/26/26.
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

import Foundation
import SwiftData

/// Parses MacDive's proprietary XML sample format and converts samples into
/// DepthSample objects attached to an existing Dive.
///
/// The XML format uses `<samples>` as the root element containing `<sample>` children:
/// ```xml
/// <samples>
///     <sample>
///         <time>1140.00</time>
///         <depth>63.88</depth>
///         <pressure>1674.00</pressure>
///         <temperature>75.00</temperature>
///         <ppo2>0.62</ppo2>
///         <ndt>33</ndt>
///     </sample>
/// </samples>
/// ```
///
/// Values are interpreted in the user's selected unit system (imperial or metric).
/// PPO2 is always in bar regardless of unit system.
struct MacDiveSampleImporter {

	enum ImportError: LocalizedError {
		case parsingFailed(String)
		case noSamplesFound

		var errorDescription: String? {
			switch self {
				case .parsingFailed(let detail): "Failed to parse MacDive samples: \(detail)"
				case .noSamplesFound: "No samples found in the pasted XML."
			}
		}
	}

	/// Parses MacDive sample XML and replaces the dive's existing depth profile.
	///
	/// - Parameters:
	///   - xml: The XML string containing `<samples>` data.
	///   - dive: The dive whose depth profile will be replaced.
	///   - unitSystem: The unit system the pasted values are expressed in.
	///   - context: The model context for inserting new samples.
	static func importSamples(
		from xml: String,
		into dive: Dive,
		unitSystem: UnitSystem,
		context: ModelContext
	) throws {
		guard let data = xml.data(using: .utf8) else {
			throw ImportError.parsingFailed("Could not read XML as UTF-8 text.")
		}

		let parser = MacDiveSampleParser(data: data, unitSystem: unitSystem)
		let samples = try parser.parse()

		guard !samples.isEmpty else {
			throw ImportError.noSamplesFound
		}

		// Remove existing depth profile samples
		for sample in dive.diveProfile ?? [] {
			context.delete(sample)
		}

		dive.diveProfile = samples
	}
}

// MARK: - XML Parser

private final class MacDiveSampleParser: NSObject, XMLParserDelegate {
	private let data: Data
	private let formatter: UnitFormatter

	private var samples: [DepthSample] = []
	private var currentElement = ""
	private var currentText = ""
	private var insideSample = false

	// Current sample fields
	private var time: Double?
	private var depth: Double?
	private var pressure: Double?
	private var temperature: Double?
	private var ppo2: Double?
	private var ndt: Int?

	private var parsingError: Error?

	init(data: Data, unitSystem: UnitSystem) {
		self.data = data
		self.formatter = UnitFormatter(system: unitSystem)
	}

	func parse() throws -> [DepthSample] {
		let parser = XMLParser(data: data)
		parser.delegate = self
		parser.shouldProcessNamespaces = false

		if !parser.parse() {
			if let error = parsingError {
				throw error
			}
			throw MacDiveSampleImporter.ImportError.parsingFailed(
				parser.parserError?.localizedDescription ?? "Unknown error"
			)
		}
		return samples
	}

	// MARK: - XMLParserDelegate

	func parser(
		_ parser: XMLParser,
		didStartElement elementName: String,
		namespaceURI: String?,
		qualifiedName: String?,
		attributes attributeDict: [String: String]
	) {
		currentElement = elementName
		currentText = ""

		if elementName == "sample" {
			insideSample = true
			time = nil
			depth = nil
			pressure = nil
			temperature = nil
			ppo2 = nil
			ndt = nil
		}
	}

	func parser(
		_ parser: XMLParser,
		didEndElement elementName: String,
		namespaceURI: String?,
		qualifiedName: String?
	) {
		guard insideSample else { return }

		let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

		switch elementName {
			case "time":
				time = Double(text)
			case "depth":
				depth = Double(text)
			case "pressure":
				pressure = Double(text)
			case "temperature":
				temperature = Double(text)
			case "ppo2":
				ppo2 = Double(text)
			case "ndt":
				ndt = Int(text)
			case "sample":
				if let time, let depth {
					let sample = DepthSample(
						elapsedSeconds: Int(time),
						depthMeters: formatter.depthToMetric(depth),
						waterTempCelsius: temperature.map { formatter.tempToMetric($0) },
						tankPressureBar: pressure.map { formatter.pressureToMetric($0) },
						ppo2Bar: ppo2,
						decoStatus: ndt != nil ? .noDecoLimit : nil,
						decoTimeSeconds: ndt.map { $0 * 60 }
					)
					samples.append(sample)
				}
				insideSample = false
			default:
				break
		}
	}

	func parser(_ parser: XMLParser, foundCharacters string: String) {
		currentText += string
	}

	func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
		parsingError = parseError
	}
}
