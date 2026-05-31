# Ethernet Status Lite

English | [中文](README.zh.md)

> Ethernet Status Lite is inspired by and restructured from [Ethernet Status](https://github.com/johanohly/ethernet-status) v26.02.18. Huge thanks to [johanohly](https://github.com/johanohly/) for the open source contribution!

Ethernet Status Lite is a lightweight macOS menu bar app that replaces the native Wi-Fi menu bar icon. It shows your actual network status at a glance — Wi-Fi (normal/hotspot), Ethernet (wired), or disconnected — and provides multiple ways to invoke the native Wi-Fi panel for switching networks.

<table style="width: 100%; border-collapse: collapse; text-align: center; vertical-align: middle;">
    <thead>
        <tr style="background-color: #f2f2f2;">
            <th style="border: 1px solid #ccc; padding: 10px; width: 30%;">Settings</th>
            <th colspan="2" style="border: 1px solid #ccc; padding: 10px; width: 70%;">Menu Bar Icon by Status</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td rowspan="5" style="border: 1px solid #ccc; padding: 10px; background-color: #fafafa;">
                <img width=100% alt="app settings" src="https://github.com/user-attachments/assets/22e0ec51-7b12-46dc-9208-8584ec31f113" />
            </td>
            <td style="border: 1px solid #ccc; padding: 10px; width: 100%;">Ethernet</td>
            <td style="border: 1px solid #ccc; padding: 10px; width: 25%;">
              <img width=100% src="https://github.com/user-attachments/assets/61443796-b60a-473f-9072-e06c7704be2a" />
            </td>
        </tr>
        <tr>
            <td style="border: 1px solid #ccc; padding: 10px;">Wi-Fi</td>
            <td style="border: 1px solid #ccc; padding: 10px;">
                <img width=100% src="https://github.com/user-attachments/assets/a2b9a3ff-5000-4e66-92d4-702d4a512418" />
            </td>
        </tr>
        <tr>
            <td style="border: 1px solid #ccc; padding: 10px;">Personal Hotspot</td>
            <td style="border: 1px solid #ccc; padding: 10px;">
                <img width=100% src="https://github.com/user-attachments/assets/ed1af49a-433c-421e-af8b-c4609fc12fb9" />
            </td>
        </tr>
        <tr>
            <td style="border: 1px solid #ccc; padding: 10px;">Wi-Fi Off</td>
            <td style="border: 1px solid #ccc; padding: 10px;">
                <img width=100% src="https://github.com/user-attachments/assets/7c73fea1-bcea-4c1a-9c55-1aacc23234ee" />
            </td>
        </tr>
        <tr>
            <td style="border: 1px solid #ccc; padding: 10px;">No Connection / Other</td>
            <td style="border: 1px solid #ccc; padding: 10px;">
                <img width=100% src="https://github.com/user-attachments/assets/0ca10050-aacd-475d-9e8d-ee9c829bc841" />
            </td>
        </tr>
    </tbody>
</table>

We recommend [Ice](https://github.com/jordanbaird/Ice), iBar, or Bartender to hide the native Wi-Fi icon.

> The motivation for Ethernet Status Lite: macOS in recent years still only shows wireless status in the native menu bar network icon, ignoring wired connections entirely. How tf can u stand that?! We wanted a Windows-style network status icon that can fully replace the native Wi-Fi menu bar icon.

## Features

> Compared with Ethernet Status v26.02.18, we removed the built-in network panel, traffic monitoring, and signal strength display. Instead, we invoke the native Wi-Fi panel for switching networks.

- Adaptive menu bar icon (Ethernet, Wi-Fi normal/hotspot, disconnected/error)
- Three ways to open the native Wi-Fi panel (Control Center(1) recommended)
- Multi-language support and customization

## Install

Download `EthernetStatusLite.dmg` from the [latest release](../../releases/latest), open it, and drag **Ethernet Status Lite** to **Applications**.

Since the app is not notarized, macOS will block it on first launch. Remove the quarantine attribute:

```sh
xattr -d com.apple.quarantine "/Applications/Ethernet Status Lite.app"
```

Then open the app. It runs in the menu bar only (no dock icon).

## Build from Source

Requires Xcode command line tools.

```sh
./build.sh
open ".build/Ethernet Status Lite.app"
```

## License & Credits

This project restructures code from [Ethernet Status](https://github.com/johanohly/ethernet-status) by [johanohly](https://github.com/johanohly/), reducing code volume by ~50% and changing the app architecture significantly. Both projects are licensed under the MIT License.
