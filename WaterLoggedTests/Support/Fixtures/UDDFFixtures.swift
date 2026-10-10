//
//  UDDFFixtures.swift
//  WaterLoggedTests
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

/// Hand-written UDDF XML fixtures covering well-formed, edge-case, and
/// malformed documents. Kept as strings so parser and import tests need no
/// bundled resource files and run entirely in memory.
enum UDDFFixtures {

	/// Wraps a fragment in a minimal UDDF 3.2.2 envelope.
	static func document(_ body: String) -> String {
		"""
		<?xml version="1.0" encoding="UTF-8"?>
		<uddf version="3.2.2">
		\(body)
		</uddf>
		"""
	}

	// MARK: - Well-formed

	/// A single dive with no site, gases, or waypoints — just the metadata that
	/// `informationafterdive` provides. Depth 18.5 m, duration 2400 s, dive #42.
	static let minimalDive = document("""
	  <profiledata>
		<repetitiongroup id="rg">
		  <dive id="dive-1">
			<informationbeforedive>
			  <datetime>2026-05-01T09:30:00</datetime>
			  <divenumber>42</divenumber>
			</informationbeforedive>
			<informationafterdive>
			  <greatestdepth>18.5</greatestdepth>
			  <diveduration>2400</diveduration>
			</informationafterdive>
		  </dive>
		</repetitiongroup>
	  </profiledata>
	""")

	/// A rich dive: EAN32 gas, a linked site, a linked buddy, a tank, and a
	/// waypoint carrying temperature (Kelvin), tank pressure, measured ppO2, and
	/// a no-deco time. Exercises most of the parser's cross-referencing.
	static let richDive = document("""
	  <diver>
		<owner id="owner-1">
		  <personal><firstname>Jane</firstname><lastname>Diver</lastname></personal>
		</owner>
		<buddy id="buddy-1">
		  <personal><firstname>Alex</firstname><lastname>Fisher</lastname></personal>
		</buddy>
	  </diver>
	  <divesite>
		<site id="site-1">
		  <name>Palancar Reef</name>
		  <geography>
			<country>Mexico</country>
			<province>Cozumel</province>
			<latitude>20.3005</latitude>
			<longitude>-87.0196</longitude>
		  </geography>
		</site>
	  </divesite>
	  <gasdefinitions>
		<mix id="mix-1">
		  <name>EAN32</name>
		  <o2>0.32</o2>
		  <he>0.0</he>
		</mix>
	  </gasdefinitions>
	  <profiledata>
		<repetitiongroup id="rg">
		  <dive id="dive-1">
			<informationbeforedive>
			  <datetime>2026-05-01T09:30:00</datetime>
			  <divenumber>142</divenumber>
			  <airtemperature>303.15</airtemperature>
			  <link ref="site-1"/>
			  <link ref="buddy-1"/>
			</informationbeforedive>
			<tankdata>
			  <link ref="mix-1"/>
			  <tankpressurebegin>20000000</tankpressurebegin>
			  <tankpressureend>6000000</tankpressureend>
			</tankdata>
			<samples>
			  <waypoint>
				<divetime>0</divetime>
				<depth>0</depth>
				<temperature>300.15</temperature>
			  </waypoint>
			  <waypoint>
				<divetime>60</divetime>
				<depth>18.5</depth>
				<temperature>293.15</temperature>
				<tankpressure>18000000</tankpressure>
				<measuredpo2>42000</measuredpo2>
				<nodecotime>1200</nodecotime>
			  </waypoint>
			</samples>
			<informationafterdive>
			  <greatestdepth>18.5</greatestdepth>
			  <diveduration>2400</diveduration>
			  <lowesttemperature>293.15</lowesttemperature>
			  <visibility>25</visibility>
			  <rating><ratingvalue>5</ratingvalue></rating>
			  <notes><para>Great dive.</para></notes>
			</informationafterdive>
		  </dive>
		</repetitiongroup>
	  </profiledata>
	""")

	/// Dive-less file with a single standalone site.
	static let sitesOnly = document("""
	  <divesite>
		<site id="site-1">
		  <name>Blue Corner</name>
		  <geography>
			<country>Palau</country>
			<latitude>7.1513</latitude>
			<longitude>134.3627</longitude>
		  </geography>
		</site>
	  </divesite>
	""")

	/// Dive-less file with two standalone buddies.
	static let buddiesOnly = document("""
	  <diver>
		<buddy id="buddy-1">
		  <personal><firstname>Alex</firstname><lastname>Fisher</lastname></personal>
		</buddy>
		<buddy id="buddy-2">
		  <personal><firstname>Sam</firstname><lastname>Reef</lastname></personal>
		</buddy>
	  </diver>
	""")

	/// Dive-less file with a single equipment item (a regulator).
	static let equipmentOnly = document("""
	  <diver>
		<owner id="owner-1">
		  <equipment>
			<regulator id="equip-1">
			  <name>MK25 EVO</name>
			  <manufacturer>Scubapro</manufacturer>
			  <model>MK25</model>
			  <serialnumber>SN-12345</serialnumber>
			</regulator>
		  </equipment>
		</owner>
	  </diver>
	""")

	/// Dive-less file with a single certification.
	static let certificationsOnly = document("""
	  <diver>
		<owner id="owner-1">
		  <education>
			<certification id="cert-1">
			  <level>Advanced Open Water</level>
			  <specialty>Deep Diver</specialty>
			  <organisation>PADI</organisation>
			  <issuedate><datetime>2025-06-15T00:00:00</datetime></issuedate>
			  <instructor><firstname>Maria</firstname><lastname>Lopez</lastname></instructor>
			</certification>
		  </education>
		</owner>
	  </diver>
	""")

	/// Dive-less file describing just the log book owner.
	static let ownerOnly = document("""
	  <diver>
		<owner id="owner-1">
		  <personal><firstname>Jane</firstname><lastname>Diver</lastname></personal>
		  <address><city>Austin</city><country>USA</country></address>
		  <contact><email>jane@example.com</email></contact>
		</owner>
	  </diver>
	""")

	/// A trip that references a dive by id.
	static let tripWithDive = document("""
	  <profiledata>
		<repetitiongroup id="rg">
		  <dive id="dive-1">
			<informationbeforedive><datetime>2026-05-01T09:30:00</datetime></informationbeforedive>
			<informationafterdive><greatestdepth>18.5</greatestdepth><diveduration>2400</diveduration></informationafterdive>
		  </dive>
		</repetitiongroup>
	  </profiledata>
	  <divetrip>
		<trip id="trip-1">
		  <name>Cozumel Spring Trip</name>
		  <trippart>
			<dateoftrip startdate="2026-05-01" enddate="2026-05-07"/>
			<geography><location>Cozumel, Mexico</location></geography>
			<relateddives><link ref="dive-1"/></relateddives>
		  </trippart>
		</trip>
	  </divetrip>
	""")

	// MARK: - Edge cases

	/// A note containing a bare ampersand — common in exports from other apps
	/// and invalid XML until the importer escapes it.
	static let bareAmpersandNote = document("""
	  <profiledata>
		<repetitiongroup id="rg">
		  <dive id="dive-1">
			<informationbeforedive><datetime>2026-05-01T09:30:00</datetime></informationbeforedive>
			<informationafterdive>
			  <greatestdepth>10</greatestdepth>
			  <notes><para>Nitrox &amp; fun with M&S gear</para></notes>
			</informationafterdive>
		  </dive>
		</repetitiongroup>
	  </profiledata>
	""")

	/// A gas mix that supplies an explicit nitrogen fraction.
	static let gasExplicitNitrogen = document("""
	  <gasdefinitions>
		<mix id="mix-1"><name>Custom</name><o2>0.30</o2><n2>0.60</n2><he>0.10</he></mix>
	  </gasdefinitions>
	""")

	/// A gas mix that omits nitrogen so it must be computed from the remainder.
	static let gasComputedNitrogen = document("""
	  <gasdefinitions>
		<mix id="mix-1"><name>Trimix</name><o2>0.21</o2><he>0.35</he></mix>
	  </gasdefinitions>
	""")

	/// Builds a single-waypoint document carrying the given raw temperature
	/// value, for exercising the Kelvin/Celsius heuristic.
	static func waypointTemperature(_ raw: String) -> String {
		document("""
		  <profiledata>
			<repetitiongroup id="rg">
			  <dive id="dive-1">
				<informationbeforedive><datetime>2026-05-01T09:30:00</datetime></informationbeforedive>
				<samples>
				  <waypoint><divetime>60</divetime><depth>10</depth><temperature>\(raw)</temperature></waypoint>
				</samples>
				<informationafterdive><greatestdepth>10</greatestdepth></informationafterdive>
			  </dive>
			</repetitiongroup>
		  </profiledata>
		""")
	}

	// MARK: - Malformed

	/// Well-formed envelope with no importable entities at all.
	static let emptyDocument = document("  <generator><name>Test</name></generator>")

	/// Truncated mid-document — the closing tags are missing.
	static let truncated = """
		<?xml version="1.0" encoding="UTF-8"?>
		<uddf version="3.2.2">
		  <profiledata>
			<repetitiongroup id="rg">
			  <dive id="dive-1">
				<informationbeforedive>
				  <datetime>2026-05-01T09:30:00
		"""

	/// A tag that is opened but never closed.
	static let unclosedTag = document("""
	  <profiledata>
		<repetitiongroup id="rg">
		  <dive id="dive-1">
			<informationafterdive>
			  <greatestdepth>10</greatestdepth>
		  </dive>
		</repetitiongroup>
	  </profiledata>
	""")
}
