# WaterLogged

WaterLogged is a scuba dive logging app for people who want to own their log book, not rent it from a service. It records
everything you'd write in a paper log — and a lot you couldn't — then lets you browse, search, chart, import, and export
it from any of your Apple devices.

WaterLogged is an **Apple-only app**. It is written entirely in Swift and SwiftUI and runs natively on **iOS**,
**iPadOS**, and **macOS** from a single shared codebase, adapting its navigation and layout to each device.

## Motivation
I wrote WaterLogged as a retired engineer and scuba enthusiast who has been diving for over 30 years. As an Apple fanatic,
I tried a number of apps for digitally recording my dives, but each suffered from one or more drawbacks:
- Logging software written by dive computer manufacturers tend to lock their customers into the manufacturer's ecosystem
and many do not have the capability (or incentive) to export dive data to another one
- Some apps are often written with cross-platform (Apple, Microsoft, Linux, Android) development in mind, with a "lowest common
denominator" user interface and no way to take advantage of Apple's unique capabilities
- Apps are often written by developers who maintain their code for a while, but eventually stop, locking the user's data
into an app that is no longer being maintained.

I  realized that in order to get what I wanted I would have to write it myself. Seeing the possibility for an interesting
retirement project and excited to dive into agentic coding, I taught myself some Swift and got a subscription to Claude.
The result is WaterLogged. It does pretty much exactly what I want it to do and I thought I would share it with the members
of the diving community who love Apple devices as much as I do. I resolved to place all of the code for WaterLogged in open
source so in case I drop dead tomorrow (or just lose interest), your dive data is not lost forever. Just find a nerd and rebuild.

WaterLogged is therefore designed to be a modern, simple app for recreational divers to record and re-live treasured diving experiences.
And although it has an impressive feature set, it will probably never be suitable for professional divers who need to record
advanced diving data. If that's what you need, there are plenty of other apps out there; or, you can fork the code base here
and start coding. Just remember the give-back requirements of the **GNU General Public License v3**.
## Features

### It's unabashedly an Apple-only app
- Written entirely in Swift, using SwiftUI and SwiftData for maximum performance, features, and look-and-feel
- Available on iOS, iPadOS, and macOS: optionally synchronized through iCloud, it's ready on any device
- Liquid Glass for that beautiful modern Apple finish
- Integrated with Siri: search dives and sites from anywhere and have them show up in your Siri search results
- Home screen widgets for when you just want a quick, small snapshot of your data

### It's free
- Really free: no purchase cost, no subscription, no in-app purchases, no ads, no account creation, no e-mails, no catch
- It's open source: [see for yourself](https://github.com/wspotmeyer/WaterLogged)
- Low barrier to entry: import your dive data through BlueTooth-enabled dive computers or through UDDF file import
- Low barrier to exit: when you grow tired of WaterLogged, export your dive data to UDDF and take it all with you somewhere else

### The log book
- **Dives** — record dive number, date and time, title, bottom time, surface interval (entered or computed from the previous
  dive), maximum depth, water and air temperature, visibility, water type, current, wave conditions, weather, protection,
  type, weight, dive guide, operator, boat, a 1–5 star rating, free-form notes, and tags.
- **Depth profiles** — full sample-by-sample profiles (depth, temperature, tank pressure, ppO₂, no-deco time, deco
  state) rendered as an interactive Swift Charts depth profile on the dive's detail view.
- **Dive sites** — name, country, region, coordinates, notes, and photos, with per-site totals such as accumulated
  dive time.
- **Trips** — group dives into trips for travel-oriented logging and statistics.
- **Buddies** — a buddy list you can populate from your contacts, with photos and per-buddy dive history.
- **Equipment and service records** — track gear by type, keep its service history, and attach it to individual dives.
- **Gas mixes and tanks** — reusable gas mix definitions with per-component fractions, plus per-dive tank entries.
- **Logbook owner and certifications** — your own diver profile and your certification history, with card images.
- **Photos** — attach photos to dives, dive sites, and buddies, view them full screen, and add, delete, or reorder
  them in a dedicated photo editing sheet.
- **Scanned log pages and signatures** — keep an image of the original paper log page and a captured verification
  signature alongside each dive.

### Browsing, search, and maps
- A map-centered home screen showing every logged dive site, with a collapsible summary bar of your headline numbers.
- Per-list search and filtering, including a tag filter strip on the dives list that combines multiple tags.
- Index bars for jumping through long lists by dive number, year, or first letter.
- Adaptive navigation: a tab bar plus Browse on iPhone, a top bar or sidebar on iPad, and a tab strip with full menu
  bar commands on the Mac.
- **Spotlight integration** — dives, dive sites, trips, and buddies are indexed on device, so a Spotlight result opens
  straight to the matching detail view via a `waterlogged://` deep link.

### Statistics

A dedicated statistics view summarizes total dives, cumulative bottom time, maximum depth, countries visited, dive
sites visited, and trips, plus charts for dives per year, dives by country and region, dives by buddy, and dives by
tag, and donut charts breaking dives down by water type and gas mix. Dives and bottom time logged before you started
using WaterLogged can be entered once in Settings as prior dive history and are added to the logbook-wide totals.

### Units and appearance

Everything is stored internally in metric (meters, Celsius, bar, kilograms, liters) and converted for display, so you
can switch between **metric and imperial** at any time without touching your data. Appearance follows the system or
can be locked to light or dark.

### iCloud sync

Turn on **Sync with iCloud** in Settings to keep your logbook in step across your iPhone, iPad, and Mac through your
own private iCloud database. Sync is off by default; with it off, your logbook stays on the device.

## Importing dives

WaterLogged is great for consolidating dive data that already exists somewhere else. It imports from several sources:

| Source | How it works |
| --- | --- |
| **Dive computers over Bluetooth** | Direct download from a Bluetooth LE dive computer using the [libdivecomputer](https://www.libdivecomputer.org) library, which is compiled into the app. Hundreds of dive computer models across all the major manufacturers are recognized; scanning, connecting, transfer progress, and a confirmation step before anything is written are all in-app. With **New Dives Only**, dives already in your logbook are recognized by their start time and skipped, and a per-computer fingerprint lets the transfer stop as soon as it reaches dives it has already downloaded. |
| **UDDF files** | Import a UDDF file exported by another dive log app. Both UDDF 2.x and 3.x are parsed, and files don't have to contain dives — a file of only dive sites, buddies, equipment, or gas mixes imports fine. |
| **Backup archives** | Restore a complete logbook, including photos and log page images, from an archive created by WaterLogged's own Backup tool. |
| **Manual entry** | Full entry forms for every record type, reachable from the app's Add buttons and, on macOS, from the `File ▸ New` menu with keyboard shortcuts. |

## Exporting data

- **UDDF export** — export your logbook as a standards-conformant UDDF file that other dive log software can read.
  Export is validated against the UDDF 3.2.2 schema, and you choose which categories to include (dives, sites,
  buddies, equipment, gas mixes, and so on); anything you leave out is omitted along with the links to it. Because the
  UDDF format can't represent everything WaterLogged stores, the export tool lists exactly what it has to leave
  behind.
- **Backup and restore** — a complete, lossless backup written as a single ZIP archive containing a UDDF file, an
  extras file for the data UDDF cannot express, and all of your saved media. Restore replaces the logbook from that
  archive, preserving record identities so relationships survive the round trip.
- **Sharing** — exports are handed off through the standard share sheet on iOS and iPadOS and the standard save panel
  on macOS.

## Tools

The Tools tab (and the macOS `File` menu) collects the utility actions: import from a dive computer, import from UDDF,
export to UDDF, back up, restore, and a **Bulk Updater** for applying the same changes to a range of dives at once.

## Requirements

- iOS 27.0, iPadOS 27.0, or macOS 27.0 or later
- Xcode 27 or later to build
- Swift 6 language mode (Swift 6.2 compiler), with `@MainActor` as the default actor isolation

## Building

Open `WaterLogged.xcodeproj` in Xcode, pick the WaterLogged scheme and a run destination, and build. There are no
package dependencies to resolve: libdivecomputer is vendored as C source under `WaterLogged/Libraries/libdivecomputer`
and compiles as part of the app target.

Unit tests live in `WaterLoggedTests` and use the Swift Testing framework, covering UDDF import and export, backup and
restore round trips, tag filtering, statistics snapshots, and model logic.

## Architecture

- **SwiftUI** for all user interface code, with `@Observable` classes for shared state.
- **SwiftData** for persistence, optionally mirrored to the user's private iCloud database through CloudKit, with models for dives, depth samples, dive sites, trips, buddies, equipment, service
  records, gas mixes, tanks, certifications, photos, and the logbook owner.
- **Modern Swift concurrency** throughout; the module defaults to `@MainActor` isolation, and the C dive computer
  bridge explicitly opts out where it must run off the main actor.
- **App Intents** for Spotlight indexing and deep-link navigation.
- **No third-party Swift dependencies.**

## License

WaterLogged is free software, licensed under the **GNU General Public License v3** — see [LICENSE.md](LICENSE.md).

It includes libdivecomputer by Jef Driesen, licensed under the GNU Lesser General Public License v2.1 or later.
Diving-related icons are licensed from [the Noun Project](https://thenounproject.com).

Copyright © 2026 John Meyer.
