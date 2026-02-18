# Ethernet Status

A lightweight macOS menubar app that replaces the native Wi-Fi menubar icon. Shows a single icon that reflects your actual connection type — Wi-Fi, Ethernet, or disconnected — with a dropdown showing connection details, live throughput graph, and nearby networks.

To hide the native Wi-Fi icon, use [Ice](https://github.com/jordanbaird/Ice) or a similar menubar manager.

## Features

- Adaptive menubar icon (Wi-Fi / Ethernet / disconnected)
- Live download/upload speed graph
- Nearby Wi-Fi networks with signal strength, band, and security info
- One-click connect/disconnect
- Launch at Login

## Install

Download `EthernetStatus.dmg` from the [latest release](../../releases/latest), open it, and drag **Ethernet Status** to **Applications**.

Since the app is not notarized, macOS will block it on first launch. Remove the quarantine attribute:

```sh
xattr -d com.apple.quarantine "/Applications/Ethernet Status.app"
```

Then open the app. It runs in the menubar only (no dock icon).

## Build from source

Requires Xcode command line tools.

```sh
./build.sh
open ".build/Ethernet Status.app"
```
