/*
 * swift_helpers.h
 *
 * Exposes libdivecomputer C macro constants as static inline functions
 * so they can be accessed from Swift (which can't import complex macros).
 */

#ifndef DC_SWIFT_HELPERS_H
#define DC_SWIFT_HELPERS_H

#include "ble.h"
#include "ioctl.h"
#include "datetime.h"
#include "descriptor.h"
#include "context.h"

#ifdef __cplusplus
extern "C" {
#endif

/* dc_descriptor_iterator is a macro wrapping dc_descriptor_iterator_new.
   Expose it as a function for Swift. */
static inline dc_status_t dc_descriptor_iterator_swift(dc_iterator_t **iterator) {
    return dc_descriptor_iterator_new(iterator, NULL);
}

/* DC_TIMEZONE_NONE is INT_MIN, not importable by Swift. */
static inline int dc_timezone_none(void) {
    return DC_TIMEZONE_NONE;
}

static inline unsigned int dc_ioctl_ble_get_name(void) {
    return DC_IOCTL_BLE_GET_NAME;
}

static inline unsigned int dc_ioctl_ble_get_pincode(void) {
    return DC_IOCTL_BLE_GET_PINCODE;
}

static inline unsigned int dc_ioctl_ble_get_accesscode(void) {
    return DC_IOCTL_BLE_GET_ACCESSCODE;
}

static inline unsigned int dc_ioctl_ble_set_accesscode(void) {
    return DC_IOCTL_BLE_SET_ACCESSCODE;
}

static inline unsigned int dc_ioctl_ble_characteristic_read(void) {
    return DC_IOCTL_BLE_CHARACTERISTIC_READ;
}

static inline unsigned int dc_ioctl_ble_characteristic_write(void) {
    return DC_IOCTL_BLE_CHARACTERISTIC_WRITE;
}

#ifdef __cplusplus
}
#endif

#endif /* DC_SWIFT_HELPERS_H */
