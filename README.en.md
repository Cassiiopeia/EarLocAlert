# EarLocAlert

**한국어**: [README.md](README.md)

[![Flutter](https://img.shields.io/badge/Flutter-3.35.5-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-lightgrey)](https://flutter.dev/multi-platform)
[![License](https://img.shields.io/badge/license-PolyForm%20Noncommercial%201.0.0-blue.svg)](LICENSE)

**A quiet, location-based alert app: it tells you you've arrived by vibration, or through your earphones only.**

When you reach a destination or leave a place, it lets you know without disturbing the people around you.

---

## Sound familiar?

- You dozed off on the shuttle bus and missed your stop
- An alarm went off in a library or an office and you wanted to disappear
- You were wearing earphones, yet the alert came out of the **speaker**

## How it works

```
Earphones connected (Bluetooth, wired or USB-C)  →  sound through the earphones only
Not connected                                    →  vibration only. The speaker stays silent
```

**The app never plays sound through the device speaker.** That is the reason it exists.

| Feature | Description |
|---|---|
| Places | Pick a spot on the map, then set a name, radius (50 m to 2 km) and alert type |
| Background monitoring | Works without keeping the app open |
| Arrive / leave alerts | When you arrive, when you leave, or both |
| Quiet alert | Repeating vibration until you dismiss it |
| Earphone detection | Checks the connection at the moment the alert fires |
| Local storage | **Your location data never leaves the device** |

---

## Status

**The app is fully implemented and is being prepared for store release.** It is not officially released yet.

| Area | Status |
|---|---|
| Specification and design docs | Done |
| App (map, places, background monitoring, alerts, alert sounds, vibration strength) | Done, 560 tests |
| Languages (Korean, English, Chinese, Japanese) | Implemented, translations not yet reviewed by native speakers |
| CI/CD pipeline | Done, Play Store release path verified |
| Android | Preparing for Google Play, real-device verification in progress |
| iOS | On hold: TestFlight signing assets expired |

Some things can only be verified on real devices (for example background monitoring under vendor battery savers). The status table in [11-ROADMAP](docs/11-ROADMAP.md) is the single source of truth for progress. The design docs in `docs/` are written in Korean.

---

## Tech stack

| Area | Used |
|---|---|
| Framework | Flutter 3.35.5 / Dart 3.9+ |
| State management | Riverpod (code generation) |
| Routing | go_router |
| Models | Freezed + json_serializable |
| Local storage | Drift (SQLite) |
| Map | Google Maps |
| Location | geolocator + platform geofencing |
| Audio | audio_session + just_audio |
| Ads | Google Mobile Ads |

## Supported platforms

- Android 8.0 (API 26) or later
- iOS 13.0 or later

> **Behavior differs by platform.** Android watches precisely with a foreground service, while iOS delegates to the OS geofencing. iOS limits monitored places to 20, and arrival detection may be delayed → [05-PLATFORM](docs/05-PLATFORM.md)

---

## Development

```bash
flutter pub get      # install dependencies
dart format .        # format
flutter test         # test
flutter run          # run
```

Builds and releases are handled by GitHub Actions → [08-OPERATIONS](docs/08-OPERATIONS.md)

See [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.

---

## Privacy

- **Location data is stored on the device only and is never sent anywhere**
- The advertising identifier is collected by the ad provider (Google AdMob)
- There is no sign-up and no account data is collected

Details: [09-RELEASE](docs/09-RELEASE.md) (Korean).

---

## License

This repository is **source-available**. It is not an OSI-approved open source license.

[PolyForm Noncommercial 1.0.0](LICENSE): reading, studying, modifying and forking are allowed for **noncommercial purposes**. Commercial use (store distribution, paid services, ad monetization, and so on) is not allowed.

The source is public so that anyone can verify that the app does not transmit location data off the device → [NOTICE](NOTICE)

## Contact

- Developer: Cassiiopeia
- Issues: [GitHub Issues](https://github.com/Cassiiopeia/EarLocAlert/issues)
- Security reports: see [SECURITY.md](SECURITY.md)
