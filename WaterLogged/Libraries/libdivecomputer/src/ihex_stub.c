/*
 * ihex_stub.c - Stub implementations for Intel HEX file support.
 *
 * The full ihex.c is excluded because it uses file I/O that is not
 * needed for BLE dive computer downloads. These stubs satisfy the
 * linker for hw_ostc.c's firmware update function.
 */

#include "ihex.h"

dc_status_t
dc_ihex_file_open (dc_ihex_file_t **file, dc_context_t *context, const char *filename)
{
	return DC_STATUS_UNSUPPORTED;
}

dc_status_t
dc_ihex_file_read (dc_ihex_file_t *file, dc_ihex_entry_t *entry)
{
	return DC_STATUS_UNSUPPORTED;
}

dc_status_t
dc_ihex_file_reset (dc_ihex_file_t *file)
{
	return DC_STATUS_UNSUPPORTED;
}

dc_status_t
dc_ihex_file_close (dc_ihex_file_t *file)
{
	return DC_STATUS_SUCCESS;
}
