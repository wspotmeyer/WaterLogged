//
//  DiveComputerManager.swift
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
import SwiftData
import SwiftUI

/// Represents the current phase of a dive computer import session.
enum DiveComputerPhase: Equatable {
	case idle
	case scanning
	case connecting(deviceName: String)
	case downloading(progress: TransferProgress)
	case reviewing(diveCount: Int)
	case importing
	case complete(importedCount: Int)
	case error(message: String)
}

/// Manages the full lifecycle of importing dives from a BLE dive computer.
///
/// The flow is: idle → scanning → connecting → downloading → reviewing → importing → complete.
/// The user can cancel at any phase, which resets back to idle.
@MainActor @Observable
final class DiveComputerManager {
	// MARK: - Published State

	var phase: DiveComputerPhase = .idle
	var discoveredDevices: [DiscoveredDevice] = []
	var downloadedDives: [ParsedDiveData] = []

	/// Whether to skip dives the log book already holds. Also controls whether the
	/// device is given its stored fingerprint, which lets it stop transferring
	/// early; turning this off forces a full re-read of the computer's log.
	var downloadNewOnly = true

	/// How much was transferred by the last download, for comparing an
	/// incremental download against a full one.
	var lastTransfer: TransferSize?

	/// Bytes moved during a download, as libdivecomputer counted them.
	struct TransferSize: Sendable, Equatable {
		var received: Int
		var expected: Int
		/// Whether the device was given a fingerprint and could stop early.
		var wasIncremental: Bool

		var formatted: String {
			let bytes = received.formatted(.byteCount(style: .memory))
			return wasIncremental
			? "\(bytes) transferred (incremental)"
			: "\(bytes) transferred (full log)"
		}
	}

	// MARK: - Private State

	private let transport = BLETransport()
	private var currentTask: Task<Void, Never>?
	private var scanTask: Task<Void, Never>?

	/// The descriptor product name for the connected device, recorded alongside
	/// its fingerprint for diagnostics.
	private var connectedDeviceModel: String?

	/// Identifies the physical device whose fingerprint we are reading and
	/// writing. The BLE peripheral identifier, because it is known before
	/// connecting and is unique per device — unlike the model name, which two
	/// identical computers would share.
	private var connectedDeviceKey: String?

	/// The serial reported by the device during the last download, if any.
	private var connectedDeviceSerial: UInt32?

	/// How many dives the device offered, so a partial import can be detected.
	private var offeredDiveCount = 0

	// MARK: - Lifecycle

	/// Begin scanning for nearby BLE dive computers.
	func startScanning() {
		reset()
		phase = .scanning

		// Start BLE scanning
		transport.start()

		scanTask = Task {
			do {
				try await transport.waitForPoweredOn()
			} catch {
				// Bluetooth is off or not authorized. Only surface the error when
				// there are no devices still listed from an earlier scan.
				if discoveredDevices.isEmpty {
					phase = .error(message: error.localizedDescription)
				}
				return
			}

			// Scan with nil services to discover all BLE peripherals.
			// Some dive computers don't advertise their service UUIDs,
			// so we must see all peripherals and filter by name.
			let stream = transport.scan()
			for await result in stream {
				let name = result.peripheral.name
				?? result.advertisementData[CBAdvertisementDataLocalNameKey] as? String
				?? "Unknown Device"

				let serviceUUIDs = result.advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]

				guard let identification = DeviceIdentifier.identify(
					name: name,
					advertisedServiceUUIDs: serviceUUIDs
				) else {
					continue
				}

				// Avoid duplicates
				let deviceId = result.peripheral.identifier
				if !discoveredDevices.contains(where: { $0.id == deviceId }) {
					discoveredDevices.append(DiscoveredDevice(
						id: deviceId,
						name: name,
						brand: identification.brand,
						rssi: result.rssi.intValue,
						transport: .ble(result.peripheral)
					))
				}
			}
		}
	}

	/// Stop the current BLE scan.
	func stopScanning() {
		transport.stopScan()
		scanTask?.cancel()
		scanTask = nil
	}

	/// Connect to a discovered device and download dives.
	///
	/// The context is needed to skip dives the log book already holds when
	/// `downloadNewOnly` is set.
	func connectAndDownload(
		_ device: DiscoveredDevice,
		context: ModelContext
	) {
		stopScanning()
		phase = .connecting(deviceName: device.name)
		connectedDeviceKey = device.id.uuidString

		currentTask = Task {
			do {
				switch device.transport {
					case .ble(let peripheral):
						try await connectAndDownloadBLE(
							peripheral,
							deviceName: device.name,
							context: context
						)
				}
			} catch is CancellationError {
				phase = .idle
			} catch {
				phase = .error(message: error.localizedDescription)
			}

			transport.disconnect()
		}
	}

	/// Download dives via BLE transport using libdivecomputer.
	private func connectAndDownloadBLE(
		_ peripheral: CBPeripheral,
		deviceName: String,
		context: ModelContext
	) async throws {
		try await transport.connect(peripheral)

		// Find the matching libdivecomputer descriptor for this device
		guard let descriptor = LibDCDeviceHandler.findDescriptor(
			deviceName: deviceName
		) else {
			throw DiveComputerError.unsupportedModel(deviceName)
		}
		defer { dc_descriptor_free(descriptor) }

		// Track the model name for fingerprint storage
		let model = LibDCDeviceHandler.productName(for: descriptor)
		connectedDeviceModel = model

		// Discover BLE services and characteristics
		phase = .downloading(progress: .discoveringServices)
		let services = try await transport.discoverServices(nil)

		let (writeChar, writeType, notifyChar) = try await findBLECharacteristics(
			services: services
		)

		phase = .downloading(progress: .connecting)

		// Hand the device the newest dive we already downloaded from it, so it can
		// stop reading as soon as it reaches that dive instead of streaming its
		// whole log. Deliberately skipped when the user wants everything, which is
		// how a dive deleted from the log book can be downloaded again.
		let storedFingerprint = downloadNewOnly
		? connectedDeviceKey.flatMap { FingerprintStore.fingerprint(forDeviceKey: $0) }
		: nil

		// Download dives from the device
		let result = try await LibDCDeviceHandler.downloadDives(
			transport: transport,
			descriptor: descriptor,
			writeCharacteristic: writeChar,
			writeType: writeType,
			notifyCharacteristic: notifyChar,
			deviceName: deviceName,
			fingerprint: storedFingerprint?.fingerprint
		) { [weak self] progress in
			self?.phase = .downloading(progress: progress)
		}

		let allDives = result.dives
		connectedDeviceSerial = result.serial
		lastTransfer = TransferSize(
			received: result.bytesReceived,
			expected: result.bytesExpected,
			wasIncremental: storedFingerprint != nil
		)

		// Drop the dives the log book already holds, if the user asked for new
		// dives only. This compares against the log book itself rather than a
		// stored last-import date, so dives that arrived by UDDF or by hand
		// are recognized too.
		let dives: [ParsedDiveData]
		if downloadNewOnly {
			dives = ImportedDiveMatcher.newDives(
				from: allDives,
				existingDates: existingDiveDates(in: context)
			)
		} else {
			dives = allDives
		}

		downloadedDives = dives
		offeredDiveCount = dives.count

		if dives.isEmpty {
			phase = .error(message: "No new dives found on the device.")
		} else {
			phase = .reviewing(diveCount: dives.count)
		}
	}

	/// Discover the write and notify characteristics for BLE communication.
	///
	/// Prioritizes known dive computer service UUIDs (Shearwater, NUS/Oceanic)
	/// before falling back to generic service discovery. This prevents
	/// accidentally connecting to the wrong service on devices that expose
	/// multiple services with write+notify characteristics.
	private func findBLECharacteristics(
		services: [CBService]
	) async throws -> (
		write: CBCharacteristic,
		writeType: CBCharacteristicWriteType,
		notify: CBCharacteristic
	) {
		// First pass: look for known dive computer services
		let knownServiceUUIDs = BLEConstants.allServiceUUIDs
		let knownServices = services.filter { knownServiceUUIDs.contains($0.uuid) }

		for service in knownServices {
			if let result = try await characteristicsFromService(service) {
				return result
			}
		}

		// Second pass: try remaining services as a fallback
		let unknownServices = services.filter { !knownServiceUUIDs.contains($0.uuid) }
		for service in unknownServices {
			if let result = try await characteristicsFromService(service) {
				return result
			}
		}

		throw DiveComputerError.protocolError(
			"No suitable BLE characteristics found on this device."
		)
	}

	/// Check a single service for write and notify characteristics.
	private func characteristicsFromService(
		_ service: CBService
	) async throws -> (
		write: CBCharacteristic,
		writeType: CBCharacteristicWriteType,
		notify: CBCharacteristic
	)? {
		let chars = try await transport.discoverCharacteristics(
			nil, for: service
		)

		let notifyChar = chars.first { $0.properties.contains(.notify) }
		let writeChar = chars.first {
			$0.properties.contains(.writeWithoutResponse)
		} ?? chars.first {
			$0.properties.contains(.write)
		}

		guard let notify = notifyChar, let write = writeChar else {
			return nil
		}

		let writeType: CBCharacteristicWriteType =
		write.properties.contains(.writeWithoutResponse)
		? .withoutResponse : .withResponse
		return (write, writeType, notify)
	}

	/// The start dates of every dive already in the log book, whatever brought
	/// them in. Used to recognize dives the device is offering for a second time.
	private func existingDiveDates(in context: ModelContext) -> [Date] {
		let descriptor = FetchDescriptor<Dive>()
		return (try? context.fetch(descriptor))?.map(\.date) ?? []
	}

	/// Remember the newest imported dive so the device can stop there next time.
	///
	/// Only advances when every offered dive was imported. If the diver
	/// deselected some, the fingerprint would sit *newer* than the dives they
	/// skipped and the device would never offer those again — the same trap the
	/// old last-import date fell into. Holding the fingerprint back costs one
	/// slower download and keeps the skipped dives reachable; duplicates are
	/// still filtered by `ImportedDiveMatcher`.
	private func recordFingerprint(forImported dives: [ParsedDiveData]) {
		guard dives.count == offeredDiveCount,
			  let key = connectedDeviceKey,
			  let newest = dives.max(by: { $0.dateTime < $1.dateTime }),
			  let fingerprint = newest.fingerprint else {
			return
		}

		FingerprintStore.save(
			DeviceFingerprint(
				fingerprint: fingerprint,
				serial: connectedDeviceSerial,
				productName: connectedDeviceModel ?? "Unknown",
				savedAt: .now
			),
			forDeviceKey: key
		)
	}

	/// Import the specified dives into SwiftData.
	func importDives(_ dives: [ParsedDiveData], into context: ModelContext) {
		guard !dives.isEmpty else { return }
		phase = .importing

		currentTask = Task {
			do {
				let count = try DiveComputerImporter.importDives(dives, into: context)

				recordFingerprint(forImported: dives)

				phase = .complete(importedCount: count)
				downloadedDives = []
			} catch {
				phase = .error(message: "Import failed: \(error.localizedDescription)")
			}
		}
	}

	/// Cancel the current operation and reset to idle.
	func cancel() {
		currentTask?.cancel()
		currentTask = nil
		stopScanning()
		transport.disconnect()
		reset()
	}

	/// Reset all state to idle.
	private func reset() {
		phase = .idle
		discoveredDevices = []
		downloadedDives = []
		connectedDeviceModel = nil
		connectedDeviceKey = nil
		connectedDeviceSerial = nil
		offeredDiveCount = 0
		lastTransfer = nil
		currentTask?.cancel()
		currentTask = nil
	}
}
