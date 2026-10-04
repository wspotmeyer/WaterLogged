//
//  BLEIOStreamBridge.swift
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

final class BLEIOStreamBridge: @unchecked Sendable {

	// MARK: - Thread-Safe Receive Queue

	/// BLE notification data arrives on MainActor, is consumed on the
	/// background thread where libdivecomputer blocks.
	///
	/// Individual BLE notifications are queued separately to preserve
	/// packet boundaries. Some protocols (e.g. Shearwater SLIP) embed
	/// per-packet framing headers that depend on each read returning
	/// exactly one notification's data.
	private let receiveLock = NSLock()
	private nonisolated(unsafe) var receiveQueue: [Data] = []
	private let dataAvailableSemaphore = DispatchSemaphore(value: 0)

	// MARK: - Write Coordination

	/// libdivecomputer (background thread) requests writes that must
	/// execute on the main thread via BLETransport.
	private let writeCompleteSemaphore = DispatchSemaphore(value: 0)

	// MARK: - Configuration

	/// Timeout in milliseconds for blocking operations.
	/// Negative means block forever. Set by libdivecomputer via set_timeout.
	private nonisolated(unsafe) var timeoutMs: Int = 5000

	/// Reference to the BLE transport and write characteristic.
	/// Only accessed on the main thread.
	private nonisolated(unsafe) weak var transport: BLETransport?
	private nonisolated(unsafe) var writeCharacteristic: CBCharacteristic?
	private nonisolated(unsafe) var writeType: CBCharacteristicWriteType = .withoutResponse

	/// The device name, returned via the BLE ioctl callback.
	private nonisolated(unsafe) var deviceName: String = ""

	/// Flag for cancellation and close.
	private nonisolated(unsafe) var isClosed = false

	// MARK: - Setup (MainActor)

	/// Configure the bridge after BLE connection is established.
	@MainActor
	func configure(
		transport: BLETransport,
		writeCharacteristic: CBCharacteristic,
		writeType: CBCharacteristicWriteType,
		deviceName: String
	) {
		self.transport = transport
		self.writeCharacteristic = writeCharacteristic
		self.writeType = writeType
		self.deviceName = deviceName
	}

	// MARK: - Data Input (MainActor → Background)

	/// Called from MainActor when BLE notification data arrives.
	@MainActor
	func onDataReceived(_ data: Data) {
		receiveLock.lock()
		receiveQueue.append(data)
		receiveLock.unlock()
		dataAvailableSemaphore.signal()
	}

	// MARK: - Synchronous Read (Background Thread)

	/// Called from background thread by libdivecomputer's read callback.
	/// Returns data from one BLE notification at a time to preserve packet
	/// boundaries required by protocols like Shearwater SLIP.
	nonisolated func synchronousRead(
		buffer: UnsafeMutablePointer<UInt8>,
		size: Int
	) -> (dc_status_t, Int) {
		let deadline: DispatchTime = timeoutMs < 0
		? .distantFuture
		: .now() + .milliseconds(timeoutMs)

		while true {
			// Try to read from the first queued packet
			receiveLock.lock()
			if !receiveQueue.isEmpty {
				let toRead = min(receiveQueue[0].count, size)
				receiveQueue[0].copyBytes(
					to: buffer,
					count: toRead
				)
				if toRead < receiveQueue[0].count {
					receiveQueue[0].removeFirst(toRead)
				} else {
					receiveQueue.removeFirst()
				}
				receiveLock.unlock()
				return (DC_STATUS_SUCCESS, toRead)
			}
			receiveLock.unlock()

			if isClosed {
				return (DC_STATUS_IO, 0)
			}

			// Block waiting for the next BLE notification
			let result = dataAvailableSemaphore.wait(timeout: deadline)
			if result == .timedOut {
				return (DC_STATUS_TIMEOUT, 0)
			}
		}
	}

	// MARK: - Synchronous Write (Background Thread → MainActor)

	/// Called from background thread by libdivecomputer's write callback.
	/// Dispatches the write to the main thread where BLETransport lives,
	/// then blocks until the write is dispatched.
	nonisolated func synchronousWrite(data: Data) -> dc_status_t {
		if isClosed { return DC_STATUS_IO }

		DispatchQueue.main.async { [weak self] in
			guard let self,
				  let transport = self.transport,
				  let characteristic = self.writeCharacteristic else {
				self?.writeCompleteSemaphore.signal()
				return
			}
			transport.write(data, to: characteristic, type: self.writeType)
			self.writeCompleteSemaphore.signal()
		}

		let deadline: DispatchTime = timeoutMs < 0
		? .distantFuture
		: .now() + .milliseconds(max(timeoutMs, 5000))
		let result = writeCompleteSemaphore.wait(timeout: deadline)
		return result == .timedOut ? DC_STATUS_TIMEOUT : DC_STATUS_SUCCESS
	}

	// MARK: - Configuration Callbacks

	nonisolated func setTimeout(milliseconds: Int) {
		timeoutMs = milliseconds
	}

	nonisolated func getDeviceName() -> String {
		deviceName
	}

	nonisolated func close() {
		isClosed = true
		dataAvailableSemaphore.signal()
	}

	nonisolated func purge() {
		receiveLock.lock()
		receiveQueue.removeAll()
		receiveLock.unlock()
	}

	nonisolated func getAvailableBytes() -> Int {
		receiveLock.lock()
		let count = receiveQueue.reduce(0) { $0 + $1.count }
		receiveLock.unlock()
		return count
	}
}
