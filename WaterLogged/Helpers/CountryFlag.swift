//
//  CountryFlag.swift
//  WaterLogged
//
//  Created by John Meyer on 4/11/26.
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

/// Converts country names, ISO 3166-1 alpha-2 codes, or alpha-3 codes into flag emoji.
struct CountryFlag {

	/// Returns the flag emoji for a country name, ISO alpha-2 code, or alpha-3 code, or nil if no match is found.
	static func emoji(for country: String) -> String? {
		let trimmed = country.trimmingCharacters(in: .whitespaces)
		guard !trimmed.isEmpty else { return nil }

		let uppercased = trimmed.uppercased()

		// If it's already a 2-letter code, convert directly
		if trimmed.count == 2 && trimmed == uppercased {
			return flagEmoji(from: uppercased)
		}

		// If it's a 3-letter code, look up the alpha-2 equivalent
		if trimmed.count == 3 && trimmed == uppercased {
			if let alpha2 = alpha3ToAlpha2[uppercased] {
				return flagEmoji(from: alpha2)
			}
		}

		// Try to match via Locale's region identifier
		let lowered = trimmed.lowercased()
		for localeID in Locale.Region.isoRegions {
			let region = Locale.Region(localeID.identifier)
			let name = Locale.current.localizedString(forRegionCode: region.identifier)?.lowercased()
			if name == lowered {
				return flagEmoji(from: region.identifier)
			}
		}

		return nil
	}

	/// ISO 3166-1 alpha-3 to alpha-2 mapping.
	private static let alpha3ToAlpha2: [String: String] = [
		"AFG": "AF", "ALB": "AL", "DZA": "DZ", "ASM": "AS", "AND": "AD",
		"AGO": "AO", "AIA": "AI", "ATA": "AQ", "ATG": "AG", "ARG": "AR",
		"ARM": "AM", "ABW": "AW", "AUS": "AU", "AUT": "AT", "AZE": "AZ",
		"BHS": "BS", "BHR": "BH", "BGD": "BD", "BRB": "BB", "BLR": "BY",
		"BEL": "BE", "BLZ": "BZ", "BEN": "BJ", "BMU": "BM", "BTN": "BT",
		"BOL": "BO", "BES": "BQ", "BIH": "BA", "BWA": "BW", "BVT": "BV",
		"BRA": "BR", "IOT": "IO", "BRN": "BN", "BGR": "BG", "BFA": "BF",
		"BDI": "BI", "CPV": "CV", "KHM": "KH", "CMR": "CM", "CAN": "CA",
		"CYM": "KY", "CAF": "CF", "TCD": "TD", "CHL": "CL", "CHN": "CN",
		"CXR": "CX", "CCK": "CC", "COL": "CO", "COM": "KM", "COG": "CG",
		"COD": "CD", "COK": "CK", "CRI": "CR", "CIV": "CI", "HRV": "HR",
		"CUB": "CU", "CUW": "CW", "CYP": "CY", "CZE": "CZ", "DNK": "DK",
		"DJI": "DJ", "DMA": "DM", "DOM": "DO", "ECU": "EC", "EGY": "EG",
		"SLV": "SV", "GNQ": "GQ", "ERI": "ER", "EST": "EE", "SWZ": "SZ",
		"ETH": "ET", "FLK": "FK", "FRO": "FO", "FJI": "FJ", "FIN": "FI",
		"FRA": "FR", "GUF": "GF", "PYF": "PF", "ATF": "TF", "GAB": "GA",
		"GMB": "GM", "GEO": "GE", "DEU": "DE", "GHA": "GH", "GIB": "GI",
		"GRC": "GR", "GRL": "GL", "GRD": "GD", "GLP": "GP", "GUM": "GU",
		"GTM": "GT", "GGY": "GG", "GIN": "GN", "GNB": "GW", "GUY": "GY",
		"HTI": "HT", "HMD": "HM", "VAT": "VA", "HND": "HN", "HKG": "HK",
		"HUN": "HU", "ISL": "IS", "IND": "IN", "IDN": "ID", "IRN": "IR",
		"IRQ": "IQ", "IRL": "IE", "IMN": "IM", "ISR": "IL", "ITA": "IT",
		"JAM": "JM", "JPN": "JP", "JEY": "JE", "JOR": "JO", "KAZ": "KZ",
		"KEN": "KE", "KIR": "KI", "PRK": "KP", "KOR": "KR", "KWT": "KW",
		"KGZ": "KG", "LAO": "LA", "LVA": "LV", "LBN": "LB", "LSO": "LS",
		"LBR": "LR", "LBY": "LY", "LIE": "LI", "LTU": "LT", "LUX": "LU",
		"MAC": "MO", "MDG": "MG", "MWI": "MW", "MYS": "MY", "MDV": "MV",
		"MLI": "ML", "MLT": "MT", "MHL": "MH", "MTQ": "MQ", "MRT": "MR",
		"MUS": "MU", "MYT": "YT", "MEX": "MX", "FSM": "FM", "MDA": "MD",
		"MCO": "MC", "MNG": "MN", "MNE": "ME", "MSR": "MS", "MAR": "MA",
		"MOZ": "MZ", "MMR": "MM", "NAM": "NA", "NRU": "NR", "NPL": "NP",
		"NLD": "NL", "NCL": "NC", "NZL": "NZ", "NIC": "NI", "NER": "NE",
		"NGA": "NG", "NIU": "NU", "NFK": "NF", "MKD": "MK", "MNP": "MP",
		"NOR": "NO", "OMN": "OM", "PAK": "PK", "PLW": "PW", "PSE": "PS",
		"PAN": "PA", "PNG": "PG", "PRY": "PY", "PER": "PE", "PHL": "PH",
		"PCN": "PN", "POL": "PL", "PRT": "PT", "PRI": "PR", "QAT": "QA",
		"REU": "RE", "ROU": "RO", "RUS": "RU", "RWA": "RW", "BLM": "BL",
		"SHN": "SH", "KNA": "KN", "LCA": "LC", "MAF": "MF", "SPM": "PM",
		"VCT": "VC", "WSM": "WS", "SMR": "SM", "STP": "ST", "SAU": "SA",
		"SEN": "SN", "SRB": "RS", "SYC": "SC", "SLE": "SL", "SGP": "SG",
		"SXM": "SX", "SVK": "SK", "SVN": "SI", "SLB": "SB", "SOM": "SO",
		"ZAF": "ZA", "SGS": "GS", "SSD": "SS", "ESP": "ES", "LKA": "LK",
		"SDN": "SD", "SUR": "SR", "SJM": "SJ", "SWE": "SE", "CHE": "CH",
		"SYR": "SY", "TWN": "TW", "TJK": "TJ", "TZA": "TZ", "THA": "TH",
		"TLS": "TL", "TGO": "TG", "TKL": "TK", "TON": "TO", "TTO": "TT",
		"TUN": "TN", "TUR": "TR", "TKM": "TM", "TCA": "TC", "TUV": "TV",
		"UGA": "UG", "UKR": "UA", "ARE": "AE", "GBR": "GB", "USA": "US",
		"UMI": "UM", "URY": "UY", "UZB": "UZ", "VUT": "VU", "VEN": "VE",
		"VNM": "VN", "VGB": "VG", "VIR": "VI", "WLF": "WF", "ESH": "EH",
		"YEM": "YE", "ZMB": "ZM", "ZWE": "ZW",
	]

	/// Converts an ISO alpha-2 country code into a flag emoji.
	private static func flagEmoji(from code: String) -> String? {
		let uppercased = code.uppercased()
		guard uppercased.count == 2 else { return nil }

		let scalars = uppercased.unicodeScalars.compactMap {
			UnicodeScalar(127397 + $0.value)
		}
		guard scalars.count == 2 else { return nil }

		return String(scalars.map { Character($0) })
	}
}

#Preview {
	let samples = [
		("Country Name", "Mexico"),
		("Country Name", "Egypt"),
		("Country Name", "Palau"),
		("Alpha-2", "US"),
		("Alpha-2", "JP"),
		("Alpha-3", "GBR"),
		("Alpha-3", "AUS"),
		("Invalid", "Atlantis"),
	]

	List {
		ForEach(samples, id: \.1) { label, input in
			HStack {
				Text(label)
					.foregroundStyle(.secondary)
					.frame(width: 120, alignment: .leading)
				Text(input)
				Spacer()
				if let flag = CountryFlag.emoji(for: input) {
					Text(flag)
				} else {
					Text("No match")
						.foregroundStyle(.tertiary)
				}
			}
		}
	}
}
