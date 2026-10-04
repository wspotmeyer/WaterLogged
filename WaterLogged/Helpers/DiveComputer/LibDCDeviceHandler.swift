//
//  LibDCDeviceHandler.swift
//  WaterLogged
//
//  Created by John Meyer on 2/23/26.
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

@preconcurrency import CoreBluetooth
import Foundation

/// Context for collecting dive data from dc_device_foreach callback.
private final class DiveCollectionContext: @unchecked Sendable {
	nonisolated(unsafe) var dives: [(data: Data, fingerprint: Data)] = []
}

/// Context for collecting samples from dc_parser_samples_foreach callback.
private final class SampleCollectionContext: @unchecked Sendable {
	nonisolated(unsafe) var samples: [ParsedSampleData] = []
	nonisolated(unsafe) var currentTimeMs: Int = 0
	/// Events that arrive before the first depth sample; flushed to the first sample once created.
	nonisolated(unsafe) var pendingEvents: [String] = []
}

// MARK: - LibDCDeviceHandler

nonisolated enum LibDCDeviceHandler {

	// MARK: - Descriptor Matching

	/// Find a libdivecomputer descriptor matching a BLE device name.
	///
	/// First tries matching the device name against known product names
	/// (case-insensitive prefix match), which returns the most specific
	/// descriptor for the actual model. Falls back to libdivecomputer's
	/// built-in `dc_descriptor_filter` for devices whose BLE name doesn't
	/// match any product name directly.
	///
	/// The product-name match is preferred because some vendors (e.g.
	/// Shearwater) use a single shared filter function for all models,
	/// causing `dc_descriptor_filter` to return the first BLE-capable
	/// descriptor rather than the correct one for the specific model.
	static func findDescriptor(
		deviceName: String
	) -> OpaquePointer? /* dc_descriptor_t* */ {
		// First pass: try matching device name against product names.
		// This returns the correct descriptor for the specific model.
		if let result = findDescriptorViaProductName(deviceName: deviceName) {
			return result
		}

		// Second pass: try libdivecomputer's built-in filter.
		// Handles devices whose BLE name doesn't match a product name
		// (e.g. Oceanic devices that use model-number-based names).
		return findDescriptorViaFilter(deviceName: deviceName)
	}

	/// Try to match using dc_descriptor_filter.
	private static func findDescriptorViaFilter(
		deviceName: String
	) -> OpaquePointer? {
		var iterator: OpaquePointer?
		guard dc_descriptor_iterator_swift(&iterator) == DC_STATUS_SUCCESS,
			  let iterator else {
			return nil
		}
		defer { dc_iterator_free(iterator) }

		var descriptor: OpaquePointer?
		while dc_iterator_next(iterator, &descriptor) == DC_STATUS_SUCCESS {
			guard let descriptor else { continue }

			let transports = dc_descriptor_get_transports(descriptor)
			guard transports & UInt32(DC_TRANSPORT_BLE.rawValue) != 0 else {
				dc_descriptor_free(descriptor)
				continue
			}

			let matched = deviceName.withCString { cName in
				dc_descriptor_filter(descriptor, DC_TRANSPORT_BLE, cName)
			}
			if matched != 0 {
				return descriptor
			}

			dc_descriptor_free(descriptor)
		}
		return nil
	}

	/// Try to match by checking if the BLE device name starts with the
	/// product name of any BLE-capable descriptor.
	///
	/// Only considers product names of 4+ characters to avoid false
	/// positives on short names (e.g. "i" or "Eon") that could match
	/// unrelated BLE peripherals.
	///
	/// When multiple product names match as prefixes (e.g. "Peregrine"
	/// and "Peregrine TX" both match "Peregrine TX"), the longest match
	/// wins to ensure the most specific descriptor is returned.
	private static func findDescriptorViaProductName(
		deviceName: String
	) -> OpaquePointer? {
		var iterator: OpaquePointer?
		guard dc_descriptor_iterator_swift(&iterator) == DC_STATUS_SUCCESS,
			  let iterator else {
			return nil
		}
		defer { dc_iterator_free(iterator) }

		let loweredName = deviceName.lowercased()

		var bestMatch: OpaquePointer?
		var bestMatchLength = 0

		var descriptor: OpaquePointer?
		while dc_iterator_next(iterator, &descriptor) == DC_STATUS_SUCCESS {
			guard let descriptor else { continue }

			let transports = dc_descriptor_get_transports(descriptor)
			guard transports & UInt32(DC_TRANSPORT_BLE.rawValue) != 0 else {
				dc_descriptor_free(descriptor)
				continue
			}

			if let cProduct = dc_descriptor_get_product(descriptor) {
				let product = String(cString: cProduct).lowercased()
				// Require at least 4 characters to avoid false positives
				// on short product names that could match unrelated devices.
				// Prefer the longest match to pick the most specific descriptor.
				if product.count >= 4,
				   product.count > bestMatchLength,
				   loweredName.hasPrefix(product) {
					if let previous = bestMatch {
						dc_descriptor_free(previous)
					}
					bestMatch = descriptor
					bestMatchLength = product.count
					continue
				}
			}

			dc_descriptor_free(descriptor)
		}
		return bestMatch
	}

	/// Get the vendor name for a descriptor (e.g. "Shearwater").
	static func vendorName(for descriptor: OpaquePointer) -> String {
		guard let cStr = dc_descriptor_get_vendor(descriptor) else {
			return "Unknown"
		}
		return String(cString: cStr)
	}

	/// Get the product name for a descriptor (e.g. "Perdix AI").
	static func productName(for descriptor: OpaquePointer) -> String {
		guard let cStr = dc_descriptor_get_product(descriptor) else {
			return "Unknown"
		}
		return String(cString: cStr)
	}

	// MARK: - Dive Download

	/// Download dives from a connected BLE dive computer. When a `fingerprint` is
	/// passed, the device stops at the first dive it has already sent, so only
	/// newer dives are transferred; without one, the whole log is read.
	///
	/// This function:
	/// 1. Sets up a BLEIOStreamBridge between CoreBluetooth and libdivecomputer
	/// 2. Runs the synchronous libdivecomputer C code on a background thread
	/// 3. Reports progress via the onProgress callback on MainActor
	/// 4. Returns parsed dives as [ParsedDiveData]
	@MainActor
	static func downloadDives(
		transport: BLETransport,
		descriptor: OpaquePointer,
		writeCharacteristic: CBCharacteristic,
		writeType: CBCharacteristicWriteType,
		notifyCharacteristic: CBCharacteristic,
		deviceName: String,
		fingerprint: Data? = nil,
		onProgress: @escaping @MainActor (TransferProgress) -> Void
	) async throws -> DiveDownloadResult {
		// Set up the bridge
		let bridge = BLEIOStreamBridge()
		bridge.configure(
			transport: transport,
			writeCharacteristic: writeCharacteristic,
			writeType: writeType,
			deviceName: deviceName
		)

		// Enable BLE notifications and forward data into the bridge
		let dataStream = try await transport.enableNotifications(
			for: notifyCharacteristic
		)

		let forwardTask = Task { @MainActor in
			for await data in dataStream {
				bridge.onDataReceived(data)
			}
		}

		defer { forwardTask.cancel() }

		onProgress(.handshaking)

		// Run the blocking libdivecomputer session on a background thread.
		nonisolated(unsafe) let descriptorCopy = descriptor
		let result: DiveDownloadResult = try await Task.detached(priority: .userInitiated) {
			try Self.runSession(
				bridge: bridge,
				descriptor: descriptorCopy,
				fingerprint: fingerprint,
				onProgress: { progress in
					DispatchQueue.main.async {
						onProgress(progress)
					}
				}
			)
		}.value

		return result
	}

	// MARK: - Session (Background Thread)

	/// Run a complete libdivecomputer download session.
	/// This function blocks and must run on a background thread.
	private static func runSession(
		bridge: BLEIOStreamBridge,
		descriptor: OpaquePointer,
		fingerprint: Data?,
		onProgress: @escaping (TransferProgress) -> Void
	) throws -> DiveDownloadResult {
		// Create context
		var context: OpaquePointer?
		var status = dc_context_new(&context)
		guard status == DC_STATUS_SUCCESS, let context else {
			throw DiveComputerError.protocolError(
				"Failed to create libdivecomputer context: \(statusDescription(status))"
			)
		}
		defer { dc_context_free(context) }

		dc_context_set_loglevel(context, DC_LOGLEVEL_WARNING)

		// Create custom iostream backed by the BLE bridge
		var cbs = makeLibDCCustomCallbacks()
		let bridgePtr = Unmanaged.passRetained(bridge).toOpaque()

		var iostream: OpaquePointer?
		status = dc_custom_open(
			&iostream, context, DC_TRANSPORT_BLE, &cbs, bridgePtr
		)
		guard status == DC_STATUS_SUCCESS, let iostream else {
			Unmanaged<BLEIOStreamBridge>.fromOpaque(bridgePtr).release()
			throw DiveComputerError.protocolError(
				"Failed to create custom iostream: \(statusDescription(status))"
			)
		}
		// The iostream now owns bridgePtr — it will be released in ldcClose

		// Open the device
		var device: OpaquePointer?
		status = dc_device_open(&device, context, descriptor, iostream)
		guard status == DC_STATUS_SUCCESS, let device else {
			dc_iostream_close(iostream)
			throw DiveComputerError.protocolError(
				"Failed to open device: \(statusDescription(status))"
			)
		}
		defer { dc_device_close(device) }

		// Subscribe to progress (byte counts) and devinfo (serial). The context
		// outlives this call, so it is passed unretained and kept alive by the
		// local binding below for the duration of the session.
		let eventContext = DeviceEventContext(onProgress: onProgress)
		let eventContextPtr = Unmanaged.passUnretained(eventContext).toOpaque()
		dc_device_set_events(
			device,
			UInt32(DC_EVENT_PROGRESS.rawValue) | UInt32(DC_EVENT_DEVINFO.rawValue),
			deviceEventCallback,
			eventContextPtr
		)

		// Tell the device which dive we already have, so it can stop reading as
		// soon as it reaches it instead of streaming its whole log. A failure
		// here is not fatal: the download just falls back to reading everything,
		// and ImportedDiveMatcher still filters out what the logbook already has.
		if let fingerprint, !fingerprint.isEmpty {
			// The status is deliberately discarded. It fails when the blob is the
			// wrong size for this backend (a fingerprint saved by a different
			// model) or when the backend implements no fingerprint support at
			// all; both mean "read everything", which is the default anyway.
			_ = fingerprint.withUnsafeBytes { buffer in
				dc_device_set_fingerprint(
					device,
					buffer.baseAddress?.assumingMemoryBound(to: UInt8.self),
					UInt32(buffer.count)
				)
			}
		}

		onProgress(.connecting)

		// Download all dives
		let diveContext = DiveCollectionContext()
		let diveContextPtr = Unmanaged.passUnretained(diveContext).toOpaque()

		status = dc_device_foreach(device, diveCallback, diveContextPtr)

		guard status == DC_STATUS_SUCCESS || status == DC_STATUS_DONE else {
			if status == DC_STATUS_CANCELLED {
				throw DiveComputerError.cancelled
			}
			throw DiveComputerError.protocolError(
				"Dive download failed: \(statusDescription(status))"
			)
		}

		let rawDives = diveContext.dives
		// With a fingerprint set, an empty result is the good outcome — the device
		// recognised its newest dive as one we already have and stopped. Only an
		// unfiltered download that comes back empty means the device has no dives.
		if rawDives.isEmpty, fingerprint == nil {
			throw DiveComputerError.noDataAvailable
		}

		// Parse each dive
		var parsedDives: [ParsedDiveData] = []
		for (index, rawDive) in rawDives.enumerated() {
			onProgress(.parsingDive(
				current: index + 1,
				total: rawDives.count
			))

			var parsed = try parseDive(
				data: rawDive.data,
				device: device,
				descriptor: descriptor
			)
			parsed.fingerprint = rawDive.fingerprint.isEmpty ? nil : rawDive.fingerprint
			if let serial = eventContext.serial {
				parsed.serialNumber = String(serial)
			}
			parsedDives.append(parsed)
		}

		onProgress(.complete(diveCount: parsedDives.count))
		return DiveDownloadResult(
			dives: parsedDives,
			serial: eventContext.serial,
			bytesReceived: eventContext.bytesReceived,
			bytesExpected: eventContext.bytesExpected
		)
	}

	// MARK: - Dive Parsing

	/// Parse a single dive's raw binary data into ParsedDiveData.
	private static func parseDive(
		data: Data,
		device: OpaquePointer,
		descriptor: OpaquePointer
	) throws -> ParsedDiveData {
		var parser: OpaquePointer?
		let status = data.withUnsafeBytes { buffer -> dc_status_t in
			guard let baseAddress = buffer.baseAddress else {
				return DC_STATUS_INVALIDARGS
			}
			return dc_parser_new(
				&parser,
				device,
				baseAddress.assumingMemoryBound(to: UInt8.self),
				buffer.count
			)
		}
		guard status == DC_STATUS_SUCCESS, let parser else {
			throw DiveComputerError.protocolError(
				"Failed to create parser: \(statusDescription(status))"
			)
		}
		defer { dc_parser_destroy(parser) }

		// Extract datetime
		var dt = dc_datetime_t()
		dc_parser_get_datetime(parser, &dt)
		var dateComponents = DateComponents()
		dateComponents.year = Int(dt.year)
		dateComponents.month = Int(dt.month)
		dateComponents.day = Int(dt.day)
		dateComponents.hour = Int(dt.hour)
		dateComponents.minute = Int(dt.minute)
		dateComponents.second = Int(dt.second)
		// dc_datetime_t.timezone is an offset in seconds, matching tm_gmtoff.
			if dt.timezone != dc_timezone_none() {
				dateComponents.timeZone = TimeZone(
				secondsFromGMT: Int(dt.timezone)
			)
		}
		let dateTime = Calendar.current.date(from: dateComponents) ?? .now

		// Extract dive time (seconds)
		var divetime: UInt32 = 0
		dc_parser_get_field(parser, DC_FIELD_DIVETIME, 0, &divetime)

		// Extract max depth (meters)
		var maxdepth: Double = 0
		dc_parser_get_field(parser, DC_FIELD_MAXDEPTH, 0, &maxdepth)

		// Extract average depth (meters)
		var avgdepth: Double = 0
		let avgStatus = dc_parser_get_field(
			parser, DC_FIELD_AVGDEPTH, 0, &avgdepth
		)
		if avgStatus != DC_STATUS_SUCCESS {
			avgdepth = 0
		}

		// Extract minimum water temperature (Celsius)
		var temperature: Double = 0
		let tempStatus = dc_parser_get_field(
			parser, DC_FIELD_TEMPERATURE_MINIMUM, 0, &temperature
		)
		let waterTemp: Double? = tempStatus == DC_STATUS_SUCCESS
		? temperature : nil

		// Extract gas mixes
		var gasmixCount: UInt32 = 0
		dc_parser_get_field(parser, DC_FIELD_GASMIX_COUNT, 0, &gasmixCount)

		var gasMixes: [ParsedGasMixData] = []
		for i in 0..<gasmixCount {
			var gasmix = dc_gasmix_t()
			let gmStatus = dc_parser_get_field(
				parser, DC_FIELD_GASMIX, i, &gasmix
			)
			if gmStatus == DC_STATUS_SUCCESS {
				let o2 = gasmix.oxygen * 100.0
				let he = gasmix.helium * 100.0
				gasMixes.append(ParsedGasMixData(
					oxygenPercent: o2,
					heliumPercent: he,
					name: gasLabel(o2: o2, he: he)
				))
			}
		}

		// Extract depth/time samples
		let sampleContext = SampleCollectionContext()
		let sampleContextPtr = Unmanaged.passUnretained(sampleContext).toOpaque()
		dc_parser_samples_foreach(parser, sampleCallback, sampleContextPtr)

		// Flush any pending events that arrived before the first depth sample
		if !sampleContext.pendingEvents.isEmpty, !sampleContext.samples.isEmpty {
			let existing = sampleContext.samples[0].events ?? []
			sampleContext.samples[0].events = sampleContext.pendingEvents + existing
			sampleContext.pendingEvents.removeAll()
		}

		// Build model name from descriptor
		let vendor = vendorName(for: descriptor)
		let product = productName(for: descriptor)

		return ParsedDiveData(
			dateTime: dateTime,
			durationSeconds: Int(divetime),
			maxDepthMeters: maxdepth,
			avgDepthMeters: avgdepth,
			waterTempCelsius: waterTemp,
			samples: sampleContext.samples,
			gasMixes: gasMixes,
			diveNumber: nil,
			computerModel: "\(vendor) \(product)",
			serialNumber: nil
		)
	}

	// MARK: - Helpers

	private static func gasLabel(o2: Double, he: Double) -> String {
		if he > 0 {
			"Trimix \(Int(o2))/\(Int(he))"
		} else if Int(o2) == 21 {
			"Air"
		} else {
			"EAN\(Int(o2))"
		}
	}

	/// Convert a dc_deco_type_t value to a `DecoType`. An unrecognized value
	/// yields nil, so the sample records no deco state rather than a guess.
	static func decoType(_ type: UInt32) -> DecoType? {
		switch dc_deco_type_t(rawValue: type) {
			case DC_DECO_NDL:        .noDecoLimit
			case DC_DECO_SAFETYSTOP: .safetyStop
			case DC_DECO_DECOSTOP:   .decoStop
			case DC_DECO_DEEPSTOP:   .deepStop
			default:                 nil
		}
	}

	/// Convert a sample event to a human-readable description.
	static func eventDescription(type: UInt32, flags: UInt32) -> String {
		let name: String
		switch parser_sample_event_t(rawValue: type) {
			case SAMPLE_EVENT_NONE:                 name = "None"
			case SAMPLE_EVENT_DECOSTOP:             name = "Deco stop"
			case SAMPLE_EVENT_RBT:                  name = "RBT"
			case SAMPLE_EVENT_ASCENT:               name = "Ascent rate"
			case SAMPLE_EVENT_CEILING:              name = "Ceiling"
			case SAMPLE_EVENT_WORKLOAD:             name = "Workload"
			case SAMPLE_EVENT_TRANSMITTER:          name = "Transmitter"
			case SAMPLE_EVENT_VIOLATION:            name = "Violation"
			case SAMPLE_EVENT_BOOKMARK:             name = "Bookmark"
			case SAMPLE_EVENT_SURFACE:              name = "Surface"
			case SAMPLE_EVENT_SAFETYSTOP:           name = "Safety stop"
			case SAMPLE_EVENT_GASCHANGE:            name = "Gas change"
			case SAMPLE_EVENT_SAFETYSTOP_VOLUNTARY: name = "Voluntary safety stop"
			case SAMPLE_EVENT_SAFETYSTOP_MANDATORY: name = "Mandatory safety stop"
			case SAMPLE_EVENT_DEEPSTOP:             name = "Deep stop"
			case SAMPLE_EVENT_CEILING_SAFETYSTOP:   name = "Ceiling safety stop"
			case SAMPLE_EVENT_FLOOR:                name = "Floor"
			case SAMPLE_EVENT_DIVETIME:             name = "Dive time"
			case SAMPLE_EVENT_MAXDEPTH:             name = "Max depth"
			case SAMPLE_EVENT_OLF:                  name = "OLF"
			case SAMPLE_EVENT_PO2:                  name = "PO2"
			case SAMPLE_EVENT_AIRTIME:              name = "Air time"
			case SAMPLE_EVENT_RGBM:                 name = "RGBM"
			case SAMPLE_EVENT_HEADING:              name = "Heading"
			case SAMPLE_EVENT_TISSUELEVEL:          name = "Tissue level"
			case SAMPLE_EVENT_GASCHANGE2:           name = "Gas change"
			default:                                name = "Event \(type)"
		}

		var suffix = ""
		if flags & UInt32(SAMPLE_FLAGS_BEGIN.rawValue) != 0 {
			suffix += " begin"
		}
		if flags & UInt32(SAMPLE_FLAGS_END.rawValue) != 0 {
			suffix += " end"
		}

		return "\(name)\(suffix)"
	}

	/// Convert a dc_status_t to a human-readable string.
	private static func statusDescription(_ status: dc_status_t) -> String {
		switch status {
			case DC_STATUS_SUCCESS: "Success"
			case DC_STATUS_DONE: "Done"
			case DC_STATUS_UNSUPPORTED: "Unsupported"
			case DC_STATUS_INVALIDARGS: "Invalid arguments"
			case DC_STATUS_NOMEMORY: "No memory"
			case DC_STATUS_NODEVICE: "No device"
			case DC_STATUS_NOACCESS: "No access"
			case DC_STATUS_IO: "I/O error"
			case DC_STATUS_TIMEOUT: "Timeout"
			case DC_STATUS_PROTOCOL: "Protocol error"
			case DC_STATUS_DATAFORMAT: "Data format error"
			case DC_STATUS_CANCELLED: "Cancelled"
			default: "Unknown error (\(status.rawValue))"
		}
	}
}

// MARK: - C Callbacks

/// Context for the device event callback. A class, not a struct, because the
/// pointer handed to libdivecomputer has to stay valid for the whole session and
/// the callback writes back into it (the serial and the final byte counts).
private final class DeviceEventContext: @unchecked Sendable {
	nonisolated(unsafe) let onProgress: (TransferProgress) -> Void
	/// Device serial from `DC_EVENT_DEVINFO`, if the backend emits one.
	nonisolated(unsafe) var serial: UInt32?
	/// The last progress figures seen, which is how much was actually transferred.
	nonisolated(unsafe) var bytesReceived = 0
	nonisolated(unsafe) var bytesExpected = 0

	nonisolated init(onProgress: @escaping (TransferProgress) -> Void) {
		self.onProgress = onProgress
	}
}

/// Device event callback for byte-level progress and device identification.
nonisolated private func deviceEventCallback(
	_ device: OpaquePointer?,
	_ event: dc_event_type_t,
	_ data: UnsafeRawPointer?,
	_ userdata: UnsafeMutableRawPointer?
) {
	guard let data, let userdata else { return }

	let ctx = Unmanaged<DeviceEventContext>.fromOpaque(userdata).takeUnretainedValue()

	switch event {
		case DC_EVENT_PROGRESS:
			let progress = data.assumingMemoryBound(to: dc_event_progress_t.self).pointee
			guard progress.maximum > 0 else { return }
			// libdivecomputer shrinks `maximum` as it works out how little it
			// actually needs to read, so the last values are the real totals.
			ctx.bytesReceived = Int(progress.current)
			ctx.bytesExpected = Int(progress.maximum)
			ctx.onProgress(.transferring(
				bytesReceived: Int(progress.current),
				totalBytes: Int(progress.maximum)
			))
		case DC_EVENT_DEVINFO:
			let info = data.assumingMemoryBound(to: dc_event_devinfo_t.self).pointee
			ctx.serial = info.serial
		default:
			break
	}
}

/// Dive data collection callback called by dc_device_foreach.
nonisolated private func diveCallback(
	_ data: UnsafePointer<UInt8>?,
	_ size: UInt32,
	_ fingerprint: UnsafePointer<UInt8>?,
	_ fsize: UInt32,
	_ userdata: UnsafeMutableRawPointer?
) -> Int32 {
	guard let data, let userdata else { return 0 }

	let context = Unmanaged<DiveCollectionContext>
		.fromOpaque(userdata).takeUnretainedValue()

	let diveData = Data(bytes: data, count: Int(size))
	let fpData: Data
	if let fingerprint {
		fpData = Data(bytes: fingerprint, count: Int(fsize))
	} else {
		fpData = Data()
	}
	context.dives.append((data: diveData, fingerprint: fpData))

	return 1 // Continue iterating
}

/// Sample data collection callback called by dc_parser_samples_foreach.
nonisolated private func sampleCallback(
	_ type: dc_sample_type_t,
	_ value: UnsafePointer<dc_sample_value_t>?,
	_ userdata: UnsafeMutableRawPointer?
) {
	guard let value, let userdata else { return }

	let context = Unmanaged<SampleCollectionContext>
		.fromOpaque(userdata).takeUnretainedValue()

	switch type {
		case DC_SAMPLE_TIME:
			context.currentTimeMs = Int(value.pointee.time)

		case DC_SAMPLE_DEPTH:
			let depth = value.pointee.depth
			context.samples.append(ParsedSampleData(
				elapsedSeconds: context.currentTimeMs / 1000,
				depthMeters: depth,
				waterTempCelsius: nil
			))

		case DC_SAMPLE_TEMPERATURE:
			if !context.samples.isEmpty {
				context.samples[context.samples.count - 1].waterTempCelsius =
				value.pointee.temperature
			}

		case DC_SAMPLE_PRESSURE:
			if !context.samples.isEmpty {
				let tank = value.pointee.pressure.tank
				let bar = value.pointee.pressure.value
				if tank == 0 {
					context.samples[context.samples.count - 1].tankPressureBar = bar
				} else if tank == 1 {
					context.samples[context.samples.count - 1].tank2PressureBar = bar
				}
			}

		case DC_SAMPLE_PPO2:
			if !context.samples.isEmpty {
				let sensor = value.pointee.ppo2.sensor
				let bar = value.pointee.ppo2.value
				switch sensor {
					case 0:
						context.samples[context.samples.count - 1].ppo2Bar = bar
					case 1:
						context.samples[context.samples.count - 1].ppo2Sensor2Bar = bar
					case 2:
						context.samples[context.samples.count - 1].ppo2Sensor3Bar = bar
					default:
						break
				}
			}

		case DC_SAMPLE_CNS:
			if !context.samples.isEmpty {
				// libdivecomputer reports CNS as 0.0–1.0 fraction; convert to 0–100%
				context.samples[context.samples.count - 1].cnsPercent =
				value.pointee.cns * 100.0
			}

		case DC_SAMPLE_SETPOINT:
			if !context.samples.isEmpty {
				context.samples[context.samples.count - 1].setpointBar =
				value.pointee.setpoint
			}

		case DC_SAMPLE_DECO:
			if !context.samples.isEmpty {
				let deco = value.pointee.deco
				let idx = context.samples.count - 1
				context.samples[idx].decoType =
				LibDCDeviceHandler.decoType(deco.type)
				context.samples[idx].decoTimeSeconds = Int(deco.time)
				context.samples[idx].decoDepthMeters = deco.depth
				context.samples[idx].decoTTSSeconds = Int(deco.tts)
			}

		case DC_SAMPLE_RBT:
			if !context.samples.isEmpty {
				// libdivecomputer reports RBT in minutes; convert to seconds
				context.samples[context.samples.count - 1].rbtSeconds =
				Int(value.pointee.rbt) * 60
			}

		case DC_SAMPLE_HEARTBEAT:
			if !context.samples.isEmpty {
				context.samples[context.samples.count - 1].heartbeatBPM =
				Int(value.pointee.heartbeat)
			}

		case DC_SAMPLE_BEARING:
			if !context.samples.isEmpty {
				context.samples[context.samples.count - 1].bearingDegrees =
				Int(value.pointee.bearing)
			}

		case DC_SAMPLE_GASMIX:
			if !context.samples.isEmpty {
				context.samples[context.samples.count - 1].activeGasMixIndex =
				Int(value.pointee.gasmix)
			}

		case DC_SAMPLE_EVENT:
			let event = value.pointee.event
			let description = LibDCDeviceHandler.eventDescription(
				type: event.type,
				flags: event.flags
			)
			if !context.samples.isEmpty {
				var existing = context.samples[context.samples.count - 1].events ?? []
				existing.append(description)
				context.samples[context.samples.count - 1].events = existing
			} else {
				context.pendingEvents.append(description)
			}

		default:
			break
	}
}
