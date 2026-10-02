**English** · [한국어](CONTRIBUTING.ko.md)

# Contributing

Thanks for your interest. Two things to know before you start.

1. This repository is **source-available** under [PolyForm Noncommercial 1.0.0](LICENSE). You may modify and fork it for noncommercial purposes, but commercial use is not allowed.
2. By sending a pull request, you agree that your contribution is covered by the same license.

## Open an issue first

Before writing code, please open an [issue](https://github.com/Cassiiopeia/EarLocAlert/issues) describing what you want to change and why. If the direction does not fit, the work can be wasted. For bugs, include the app version, platform and device, and reproduction steps. An exported diagnostics log (Settings, Diagnostics) helps us find the cause fastest.

## Principles that must be kept

These are tied directly to why the app exists and have **no exceptions**. The reasoning is in [CLAUDE.md](CLAUDE.md) and `docs/` (written in Korean).

- **Never play sound without confirming that earphones are connected.** If the check fails, fall back to vibration
- Dismissing an alert never waits for an ad. Never overlay an ad on the alert screen
- Log through `Diagnostics`, not `print`
- Do not hardcode UI strings. Use the four-language l10n (`context.l10n.key`)
- State management uses `@riverpod` code generation only

## Development environment

- Flutter 3.35.5 (Dart 3.9+). Newer versions may break code generation
- To see the map, copy `.env.example` to `.env` and fill in `MAPS_API_KEY`. The build works without it and the map is simply gray
- **Do not use real ad IDs for device testing.** Debug builds switch to test ad IDs automatically

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```

## Sending a pull request

- Keep changes small, with one purpose per pull request
- If you change a design decision, add an entry to [10-DECISIONS](docs/10-DECISIONS.md)
- Do not edit the version in `pubspec.yaml`. `version.yml` is the single source
- For changes that can only be verified on a real device (background behavior, audio routing), say which device you verified on

## Security issues

Do not report vulnerabilities in a public issue. Follow [SECURITY.md](SECURITY.md).
