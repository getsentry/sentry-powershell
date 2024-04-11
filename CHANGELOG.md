# Changelog

## Unreleased

### Features

- Send events synchronously so they're not lost when the script exits ([#39](https://github.com/getsentry/sentry-powershell/pull/39))

### Fixes

- Transaction sampling ([#38](https://github.com/getsentry/sentry-powershell/pull/41))

### Dependencies

- Bump Dotnet SDK from v4.1.2 to v4.3.0 ([#44](https://github.com/getsentry/sentry-powershell/pull/44))
  - [changelog](https://github.com/getsentry/sentry-dotnet/blob/main/CHANGELOG.md#430)
  - [diff](https://github.com/getsentry/sentry-dotnet/compare/4.1.2...4.3.0)

## 0.0.2

### Various fixes & improvements

- add changelog (c5bcf218) by @vaind
- chore: use env file to change craft log level (4431f857) by @vaind
- chore: change craft log level to trace (77ffea0c) by @vaind
- docs: add sentry psgallery link (bd550ba5) by @vaind
- fixup psd links (9b04cf8a) by @vaind

## 0.0.1

Initial manual release of the PowerShell Sentry SDK.
