/*
 * config.h - Manual configuration for iOS/macOS Xcode build
 *
 * This replaces the autotools-generated config.h for direct Xcode compilation.
 */

#ifndef CONFIG_H
#define CONFIG_H

/* Package info */
#define PACKAGE "libdivecomputer"
#define PACKAGE_VERSION "0.10.0-devel"
#define VERSION "0.10.0-devel"
#define PACKAGE_STRING "libdivecomputer 0.10.0-devel"
#define PACKAGE_BUGREPORT "https://www.libdivecomputer.org"

/* Enable logging support */
#define ENABLE_LOGGING 1

/* Timer support — Darwin uses mach_absolute_time */
#define HAVE_MACH_MACH_TIME_H 1

/* Time functions available on Darwin */
#define HAVE_LOCALTIME_R 1
#define HAVE_GMTIME_R 1
#define HAVE_TIMEGM 1

/* pthreads */
#define HAVE_PTHREAD_H 1

/* IOKit serial header (macOS only, not iOS) */
#ifdef __APPLE__
#include <TargetConditionals.h>
#if TARGET_OS_OSX
#define HAVE_IOKIT_SERIAL_IOSS_H 1
#endif
#endif

/* Transport backends NOT available — excluded from build:
 * - libusb (HAVE_LIBUSB)
 * - HIDAPI (HAVE_HIDAPI)
 * - BlueZ (HAVE_BLUEZ)
 * - Windows sockets (HAVE_WINSOCK2_H, HAVE_WS2BTH_H)
 * - IrDA (HAVE_AF_IRDA_H, HAVE_LINUX_IRDA_H)
 * - Linux serial (HAVE_LINUX_SERIAL_H)
 */

#endif /* CONFIG_H */
