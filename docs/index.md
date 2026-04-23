---
layout: default
title: Shellbee Support
description: Get help with Shellbee, a native iOS app for Zigbee2MQTT.
---

# Shellbee Support

Shellbee is a native iOS app that connects to a [Zigbee2MQTT](https://www.zigbee2mqtt.io) bridge over WebSocket and lets you monitor and control your Zigbee network from your iPhone or iPad.

This page is the official support resource for the app. If you have a question, run into a bug, or want to request a feature, you're in the right place.

## Contact

The fastest way to reach the developer is email:

**[kenneth@echodb.dev](mailto:kenneth@echodb.dev?subject=Shellbee%20Support)**

We aim to reply within 2 business days. Please include:

- The version of Shellbee you're running (Settings → About).
- Your iOS / iPadOS version and device model.
- The version of Zigbee2MQTT your bridge is running.
- A description of what you were doing and what went wrong.
- Screenshots or screen recordings, if relevant.

## Report a bug or request a feature

Public bug reports and feature requests are tracked on GitHub:

- [Open an issue](https://github.com/tashda/shellbee/issues/new/choose)
- [Browse existing issues](https://github.com/tashda/shellbee/issues)

A GitHub account is required to file issues directly. If you don't have one and don't want to create one, email us at [kenneth@echodb.dev](mailto:kenneth@echodb.dev) and we'll file the report on your behalf.

## Requirements

- iPhone or iPad running **iOS / iPadOS 17 or later**.
- A reachable Zigbee2MQTT instance (version 1.33 or later recommended) with the WebSocket/frontend enabled.
- A valid authentication token for the bridge, if your instance requires one.

## Frequently asked questions

### How do I connect Shellbee to my Zigbee2MQTT bridge?

Open the app, tap **Add Server**, and enter your bridge's WebSocket URL. Shellbee supports both `ws://` (LAN) and `wss://` (TLS) connections. On the local network, Shellbee can also discover `.local` hosts via Bonjour.

If your bridge requires an auth token, paste it into the **Token** field. Tokens are stored in the iOS Keychain, not in `UserDefaults`.

### I get "Connection refused" or "Cannot connect."

- Confirm the bridge's frontend/WebSocket is enabled in `configuration.yaml` (`frontend: true`).
- Confirm the port is reachable from your iPhone (try the URL in Safari on the same device).
- If using `wss://`, make sure your TLS certificate is trusted by iOS.
- If your bridge is behind a reverse proxy, make sure WebSocket upgrades are forwarded.

### Does Shellbee work over the internet?

Yes, as long as your Zigbee2MQTT bridge is reachable from the device — typically via a VPN (Tailscale, WireGuard) or a reverse-proxied `wss://` endpoint. Shellbee itself does not proxy your data through any third-party server.

### Does Shellbee collect any personal data?

No. Shellbee communicates directly with the Zigbee2MQTT bridge you configure. It does not include analytics, tracking, or third-party SDKs. See our [Privacy Policy](privacy.html) for details.

### Which devices and features are supported?

Shellbee generates controls from Zigbee2MQTT's `exposes` metadata, so it automatically supports most devices that Z2M supports, including lights (on/off, brightness, color), switches, covers, fans, climate devices, locks, and a wide range of sensors.

### Does Shellbee support Live Activities?

Yes. Connection state and OTA update progress can appear as a Live Activity on the Lock Screen and in the Dynamic Island on supported iPhones.

### How do I update firmware on a Zigbee device?

From the device detail screen, open the action menu and choose **Check for updates**. If an update is available, you can start it from there. OTA progress appears as a Live Activity while the update runs.

## Documentation

Shellbee bundles offline documentation for common Zigbee devices. You can also refer to the upstream [Zigbee2MQTT documentation](https://www.zigbee2mqtt.io/guide/) for bridge-side configuration.

## Privacy

See the [Shellbee Privacy Policy](privacy.html).

## About

Shellbee is developed by Kenneth Tashda.
Source: [github.com/tashda/shellbee](https://github.com/tashda/shellbee)
License: AGPL-3.0
