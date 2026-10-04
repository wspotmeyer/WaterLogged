//
//  BLETransport.swift
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

/// Errors that can occur during BLE operations.
enum BLETransportError: LocalizedError, Sendable {
	case bluetoothUnavailable(CBManagerState)
	case connectionFailed(String)
	case characteristicNotFound(CBUUID)
	case notifySetupFailed(String)

	var errorDescription: String? {
		switch self {
			case .bluetoothUnavailable:
				"Bluetooth is not available. Please enable Bluetooth in Settings."
			case .connectionFailed(let detail):
				"Failed to connect: \(detail)"
			case .characteristicNotFound:
				"Required characteristic not found on device."
			case .notifySetupFailed(let detail):
				"Failed to enable notifications: \(detail)"
		}
	}
}

/// A single BLE scan result, marked `@unchecked Sendable` because CoreBluetooth
/// guarantees the advertisement dictionary is safe to read after delivery.
struct BLEScanResult: @unchecked Sendable {
	nonisolated(unsafe) let peripheral: CBPeripheral
	nonisolated(unsafe) let advertisementData: [String: Any]
	let rssi: NSNumber
}

/// Low-level async/await wrapper around CoreBluetooth.
///
/// All methods run on `@MainActor` because `CBCentralManager` is created
/// with `queue: nil` (main queue callbacks), keeping everything thread-safe.
@MainActor
final class BLETransport: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
	private var centralManager: CBCentralManager?
	private var connectedPeripheral: CBPeripheral?

	// One-shot continuations for async bridging
	private var stateContinuation: CheckedContinuation<CBManagerState, Never>?
	private var connectContinuation: CheckedContinuation<Void, any Error>?
	private var serviceDiscoveryContinuation: CheckedContinuation<[CBService], any Error>?
	private var characteristicDiscoveryContinuation: CheckedContinuation<[CBCharacteristic], any Error>?
	private var notifyContinuation: CheckedContinuation<Void, any Error>?

	// Streaming continuations
	private var scanStream: AsyncStream<BLEScanResult>.Continuation?
	private var dataStreamContinuation: AsyncStream<Data>.Continuation?

	/// Initialize the central manager. Call this before any BLE operations.
	func start() {
		centralManager = CBCentralManager(delegate: self, queue: nil)
	}

	/// Wait until Bluetooth is powered on.
	func waitForPoweredOn() async throws {
		guard let cm = centralManager else {
			throw BLETransportError.bluetoothUnavailable(.unknown)
		}
		if cm.state == .poweredOn { return }

		let state = await withCheckedContinuation { (continuation: CheckedContinuation<CBManagerState, Never>) in
			self.stateContinuation = continuation
		}
		if state != .poweredOn {
			throw BLETransportError.bluetoothUnavailable(state)
		}
	}

	/// Scan for BLE peripherals.
	///
	/// Pass service UUIDs to filter by advertised services, or `nil` to discover
	/// all peripherals (needed for devices that don't advertise service UUIDs).
	func scan(
		forServicesWithUUIDs uuids: [CBUUID]? = nil
	) -> AsyncStream<BLEScanResult> {
		AsyncStream { continuation in
			self.scanStream = continuation
			continuation.onTermination = { @Sendable [weak self] _ in
				Task { @MainActor [weak self] in
					self?.centralManager?.stopScan()
				}
			}
			self.centralManager?.scanForPeripherals(withServices: uuids, options: [
				CBCentralManagerScanOptionAllowDuplicatesKey: false
			])
		}
	}

	/// Stop the current scan.
	func stopScan() {
		centralManager?.stopScan()
		scanStream?.finish()
		scanStream = nil
	}

	/// Connect to a peripheral.
	func connect(_ peripheral: CBPeripheral) async throws {
		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
			self.connectContinuation = continuation
			peripheral.delegate = self
			self.connectedPeripheral = peripheral
			self.centralManager?.connect(peripheral, options: nil)
		}
	}

	/// Discover services on the connected peripheral.
	func discoverServices(_ uuids: [CBUUID]?) async throws -> [CBService] {
		guard let peripheral = connectedPeripheral else {
			throw BLETransportError.connectionFailed("No connected peripheral")
		}
		return try await withCheckedThrowingContinuation { continuation in
			self.serviceDiscoveryContinuation = continuation
			peripheral.discoverServices(uuids)
		}
	}

	/// Discover characteristics for a service.
	func discoverCharacteristics(
		_ uuids: [CBUUID]?,
		for service: CBService
	) async throws -> [CBCharacteristic] {
		guard let peripheral = connectedPeripheral else {
			throw BLETransportError.connectionFailed("No connected peripheral")
		}
		return try await withCheckedThrowingContinuation { continuation in
			self.characteristicDiscoveryContinuation = continuation
			peripheral.discoverCharacteristics(uuids, for: service)
		}
	}

	/// Enable notifications on a characteristic and return a stream of received data.
	func enableNotifications(
		for characteristic: CBCharacteristic
	) async throws -> AsyncStream<Data> {
		guard let peripheral = connectedPeripheral else {
			throw BLETransportError.connectionFailed("No connected peripheral")
		}

		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
			self.notifyContinuation = continuation
			peripheral.setNotifyValue(true, for: characteristic)
		}

		return AsyncStream<Data> { continuation in
			self.dataStreamContinuation = continuation
			continuation.onTermination = { @Sendable [weak self] _ in
				Task { @MainActor [weak self] in
					guard let self, let peripheral = self.connectedPeripheral else { return }
					if characteristic.isNotifying {
						peripheral.setNotifyValue(false, for: characteristic)
					}
				}
			}
		}
	}

	/// Write data to a characteristic.
	func write(
		_ data: Data,
		to characteristic: CBCharacteristic,
		type: CBCharacteristicWriteType = .withResponse
	) {
		connectedPeripheral?.writeValue(data, for: characteristic, type: type)
	}

	/// Disconnect from the current peripheral.
	func disconnect() {
		if let peripheral = connectedPeripheral {
			centralManager?.cancelPeripheralConnection(peripheral)
		}
		dataStreamContinuation?.finish()
		dataStreamContinuation = nil
		connectedPeripheral = nil
	}

	// MARK: - CBCentralManagerDelegate

	nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
		MainActor.assumeIsolated {
			stateContinuation?.resume(returning: central.state)
			stateContinuation = nil
		}
	}

	nonisolated func centralManager(
		_ central: CBCentralManager,
		didDiscover peripheral: CBPeripheral,
		advertisementData: [String: Any],
		rssi RSSI: NSNumber
	) {
		let result = BLEScanResult(peripheral: peripheral, advertisementData: advertisementData, rssi: RSSI)
		_ = MainActor.assumeIsolated {
			self.scanStream?.yield(result)
		}
	}

	nonisolated func centralManager(
		_ central: CBCentralManager,
		didConnect peripheral: CBPeripheral
	) {
		MainActor.assumeIsolated {
			connectContinuation?.resume()
			connectContinuation = nil
		}
	}

	nonisolated func centralManager(
		_ central: CBCentralManager,
		didFailToConnect peripheral: CBPeripheral,
		error: (any Error)?
	) {
		MainActor.assumeIsolated {
			connectContinuation?.resume(
				throwing: BLETransportError.connectionFailed(
					error?.localizedDescription ?? "Unknown error"
				)
			)
			connectContinuation = nil
		}
	}

	nonisolated func centralManager(
		_ central: CBCentralManager,
		didDisconnectPeripheral peripheral: CBPeripheral,
		error: (any Error)?
	) {
		MainActor.assumeIsolated {
			dataStreamContinuation?.finish()
			dataStreamContinuation = nil
			connectedPeripheral = nil
		}
	}

	// MARK: - CBPeripheralDelegate

	nonisolated func peripheral(
		_ peripheral: CBPeripheral,
		didDiscoverServices error: (any Error)?
	) {
		nonisolated(unsafe) let services = peripheral.services ?? []
		MainActor.assumeIsolated {
			if let error {
				serviceDiscoveryContinuation?.resume(
					throwing: BLETransportError.connectionFailed(error.localizedDescription)
				)
			} else {
				serviceDiscoveryContinuation?.resume(returning: services)
			}
			serviceDiscoveryContinuation = nil
		}
	}

	nonisolated func peripheral(
		_ peripheral: CBPeripheral,
		didDiscoverCharacteristicsFor service: CBService,
		error: (any Error)?
	) {
		nonisolated(unsafe) let characteristics = service.characteristics ?? []
		nonisolated(unsafe) let uuid = service.uuid
		MainActor.assumeIsolated {
			if error != nil {
				characteristicDiscoveryContinuation?.resume(
					throwing: BLETransportError.characteristicNotFound(uuid)
				)
			} else {
				characteristicDiscoveryContinuation?.resume(
					returning: characteristics
				)
			}
			characteristicDiscoveryContinuation = nil
		}
	}

	nonisolated func peripheral(
		_ peripheral: CBPeripheral,
		didUpdateNotificationStateFor characteristic: CBCharacteristic,
		error: (any Error)?
	) {
		MainActor.assumeIsolated {
			if let error {
				notifyContinuation?.resume(
					throwing: BLETransportError.notifySetupFailed(error.localizedDescription)
				)
			} else {
				notifyContinuation?.resume()
			}
			notifyContinuation = nil
		}
	}

	nonisolated func peripheral(
		_ peripheral: CBPeripheral,
		didUpdateValueFor characteristic: CBCharacteristic,
		error: (any Error)?
	) {
		MainActor.assumeIsolated {
			if let data = characteristic.value {
				dataStreamContinuation?.yield(data)
			}
		}
	}
}
