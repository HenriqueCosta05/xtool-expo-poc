# Build React Native and Expo apps

Build, sign, and install a React Native or Expo app on Linux, WSL, or macOS.

## Overview

xtool builds React Native apps using the precompiled XCFrameworks and Swift Package Manager tooling that ship with React Native. It runs React Native's own SwiftPM pipeline, generates a small Swift package for your app, and then builds, signs, and installs it like any other xtool app.

> Note: This requires react-native 0.87 or newer (Expo SDK 56 or newer). Every native module you use must support SwiftPM: either ship a `Package.swift`, or ship precompiled XCFrameworks (most Expo modules do).

## Requirements

In addition to the steps in <doc:Installation-Linux>, install [Node.js](https://nodejs.org) 20 or newer, and Python 3 on Linux. Then install your app's dependencies:

```bash
npm install
```

Optionally add an `xtool.yml` to the root of your project to set the bundle ID. The same keys as for SwiftPM apps apply, except `product` and `extensions`.

```yaml
version: 1
bundleID: com.example.myapp
```

## Build and run

From the root of your project (the folder with `package.json`), run:

```bash
xtool dev
```

xtool detects the React Native project, prepares it in `xtool/rn`, and installs the app on your connected device.

### Debug builds

Debug builds load JavaScript from the Metro dev server, so start it in a separate terminal:

```bash
npx expo start  # or: npx react-native start
```

The app connects to Metro using your machine's IP address. To use a different host, set `XTOOL_METRO_HOST`:

```bash
XTOOL_METRO_HOST=192.168.1.20 xtool dev
```

> Important: On WSL 2 the default NAT network isn't reachable from your phone. Enable [mirrored networking mode](https://learn.microsoft.com/en-us/windows/wsl/networking#mirrored-mode-networking) so that WSL shares your PC's IP address, and allow port 8081 through the Windows firewall.

### Release builds

Release builds embed the JavaScript bundle and assets in the app, so they run without Metro:

```bash
xtool dev run -c release
xtool dev build -c release --ipa
```
