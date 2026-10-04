//
//  LibDCCallbacks.swift
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

import Foundation

// MARK: - Custom I/O Stream Callbacks

/// Set the read timeout in milliseconds.
nonisolated private func ldcSetTimeout(
	_ userdata: UnsafeMutableRawPointer?,
	_ timeout: Int32
) -> dc_status_t {
	guard let userdata else { return DC_STATUS_INVALIDARGS }
	let bridge = Unmanaged<BLEIOStreamBridge>
		.fromOpaque(userdata).takeUnretainedValue()
	bridge.setTimeout(milliseconds: Int(timeout))
	return DC_STATUS_SUCCESS
}

/// Read data from the BLE stream. Blocks until data is available.
nonisolated private func ldcRead(
	_ userdata: UnsafeMutableRawPointer?,
	_ data: UnsafeMutableRawPointer?,
	_ size: Int,
	_ actual: UnsafeMutablePointer<Int>?
) -> dc_status_t {
	guard let userdata, let data, let actual else {
		return DC_STATUS_INVALIDARGS
	}
	let bridge = Unmanaged<BLEIOStreamBridge>
		.fromOpaque(userdata).takeUnretainedValue()
	let buffer = data.assumingMemoryBound(to: UInt8.self)
	let (status, bytesRead) = bridge.synchronousRead(
		buffer: buffer, size: size
	)
	actual.pointee = bytesRead
	return status
}

/// Write data to the BLE stream. Dispatches to MainActor.
nonisolated private func ldcWrite(
	_ userdata: UnsafeMutableRawPointer?,
	_ data: UnsafeRawPointer?,
	_ size: Int,
	_ actual: UnsafeMutablePointer<Int>?
) -> dc_status_t {
	guard let userdata, let data, let actual else {
		return DC_STATUS_INVALIDARGS
	}
	let bridge = Unmanaged<BLEIOStreamBridge>
		.fromOpaque(userdata).takeUnretainedValue()
	let writeData = Data(bytes: data, count: size)
	let status = bridge.synchronousWrite(data: writeData)
	actual.pointee = (status == DC_STATUS_SUCCESS) ? size : 0
	return status
}

/// Handle ioctl requests, primarily BLE device name queries.
nonisolated private func ldcIoctl(
	_ userdata: UnsafeMutableRawPointer?,
	_ request: UInt32,
	_ data: UnsafeMutableRawPointer?,
	_ size: Int
) -> dc_status_t {
	guard let userdata else { return DC_STATUS_INVALIDARGS }
	let bridge = Unmanaged<BLEIOStreamBridge>
		.fromOpaque(userdata).takeUnretainedValue()

	// Handle BLE GET_NAME ioctl
	if request == dc_ioctl_ble_get_name() {
		guard let data else { return DC_STATUS_INVALIDARGS }
		let name = bridge.getDeviceName()
		let cString = name.utf8CString
		let bytesToCopy = min(cString.count, size)
		cString.withUnsafeBufferPointer { buffer in
			data.copyMemory(
				from: buffer.baseAddress!,
				byteCount: bytesToCopy
			)
		}
		return DC_STATUS_SUCCESS
	}

	return DC_STATUS_UNSUPPORTED
}

/// Flush output buffer (no-op for BLE).
nonisolated private func ldcFlush(
	_ userdata: UnsafeMutableRawPointer?
) -> dc_status_t {
	DC_STATUS_SUCCESS
}

/// Purge input/output buffers.
nonisolated private func ldcPurge(
	_ userdata: UnsafeMutableRawPointer?,
	_ direction: dc_direction_t
) -> dc_status_t {
	guard let userdata else { return DC_STATUS_INVALIDARGS }
	let bridge = Unmanaged<BLEIOStreamBridge>
		.fromOpaque(userdata).takeUnretainedValue()
	bridge.purge()
	return DC_STATUS_SUCCESS
}

/// Sleep for the specified number of milliseconds.
nonisolated private func ldcSleep(
	_ userdata: UnsafeMutableRawPointer?,
	_ milliseconds: UInt32
) -> dc_status_t {
	Thread.sleep(forTimeInterval: Double(milliseconds) / 1000.0)
	return DC_STATUS_SUCCESS
}

/// Close the stream and release the bridge reference.
nonisolated private func ldcClose(
	_ userdata: UnsafeMutableRawPointer?
) -> dc_status_t {
	guard let userdata else { return DC_STATUS_INVALIDARGS }
	let bridge = Unmanaged<BLEIOStreamBridge>
		.fromOpaque(userdata).takeUnretainedValue()
	bridge.close()
	// Release the retained reference created when the iostream was opened
	Unmanaged<BLEIOStreamBridge>.fromOpaque(userdata).release()
	return DC_STATUS_SUCCESS
}

/// Query the number of available bytes in the receive buffer.
nonisolated private func ldcGetAvailable(
	_ userdata: UnsafeMutableRawPointer?,
	_ value: UnsafeMutablePointer<Int>?
) -> dc_status_t {
	guard let userdata, let value else { return DC_STATUS_INVALIDARGS }
	let bridge = Unmanaged<BLEIOStreamBridge>
		.fromOpaque(userdata).takeUnretainedValue()
	value.pointee = bridge.getAvailableBytes()
	return DC_STATUS_SUCCESS
}

/// Poll for available data with a timeout.
nonisolated private func ldcPoll(
	_ userdata: UnsafeMutableRawPointer?,
	_ timeout: Int32
) -> dc_status_t {
	guard let userdata else { return DC_STATUS_INVALIDARGS }
	let bridge = Unmanaged<BLEIOStreamBridge>
		.fromOpaque(userdata).takeUnretainedValue()

	// Check if data is already available
	if bridge.getAvailableBytes() > 0 {
		return DC_STATUS_SUCCESS
	}

	// If non-blocking, return immediately
	if timeout == 0 {
		return DC_STATUS_TIMEOUT
	}

	// Wait for data (the read will handle the actual blocking)
	// Do a single-byte read peek using the semaphore indirectly
	Thread.sleep(forTimeInterval: Double(min(timeout, 100)) / 1000.0)
	return bridge.getAvailableBytes() > 0
	? DC_STATUS_SUCCESS
	: DC_STATUS_TIMEOUT
}

// MARK: - Callback Struct Builder

/// Build the dc_custom_cbs_t struct with all our callback functions.
nonisolated func makeLibDCCustomCallbacks() -> dc_custom_cbs_t {
	dc_custom_cbs_t(
		set_timeout: ldcSetTimeout,
		set_break: nil,
		set_dtr: nil,
		set_rts: nil,
		get_lines: nil,
		get_available: ldcGetAvailable,
		configure: nil,
		poll: ldcPoll,
		read: ldcRead,
		write: ldcWrite,
		ioctl: ldcIoctl,
		flush: ldcFlush,
		purge: ldcPurge,
		sleep: ldcSleep,
		close: ldcClose
	)
}
