# Ethernet Status

A lightweight macOS menubar app that shows your active network connection type. Designed to replace the system Wi-Fi icon (hidden via [Ice](https://github.com/jordanbaird/Ice) or similar) with a single icon that reflects what you're actually using.

| State         | Icon                                          |
| ------------- | --------------------------------------------- |
| Wi-Fi         | `wifi` / `wifi.exclamationmark` (weak signal) |
| Ethernet      | `link`                                        |
| No connection | `wifi.slash`                                  |

<!-- ![menubar screenshot](screenshot.png) -->

Click the icon to see connection details: interface name, IP address, Wi-Fi SSID & signal strength, or ethernet link speed.

## Install

Download `EthernetStatus.zip` from the [latest release](../../releases/latest), unzip, and move `Ethernet Status.app` to `/Applications`.

Since the app is not notarized, macOS will block it on first launch. Remove the quarantine attribute:

```sh
xattr -d com.apple.quarantine "/Applications/Ethernet Status.app"
```

Then open the app. It runs in the menubar only (no dock icon).

To start at login, add it in **System Settings > General > Login Items**.

## Build from source

Requires Xcode command line tools.

```sh
./build.sh
open ".build/Ethernet Status.app"
```
