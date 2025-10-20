# Changelog

## Unreleased

### Fixes

- Fix PowerShell 7.5.2+ compatibility for SynchronousTransport ([#105](https://github.com/getsentry/sentry-powershell/pull/105))

### Dependencies

- Bump Dotnet SDK from v5.4.0 to v5.16.1 ([#83](https://github.com/getsentry/sentry-powershell/pull/83), [#89](https://github.com/getsentry/sentry-powershell/pull/89))
  - [changelog](https://github.com/getsentry/sentry-dotnet/blob/main/CHANGELOG.md#5161)
  - [diff](https://github.com/getsentry/sentry-dotnet/compare/5.4.0...5.16.1)

## 0.3.0

### Breaking changes

- Drop support for PowerShell 7.2 and 7.3 ([#71](https://github.com/getsentry/sentry-powershell/pull/71))

### Fixes

- Attachments support regression introduced in v0.2.0 ([#80](https://github.com/getsentry/sentry-powershell/pull/80))
- Diagnostic logs: exceptions didn't have full context ([#81](https://github.com/getsentry/sentry-powershell/pull/81))

### Features

- Add support for PowerShell 7.5 ([#76](https://github.com/getsentry/sentry-powershell/pull/76))

### Dependencies

- Bump Dotnet SDK from v4.13.0 to v5.4.0 ([#71](https://github.com/getsentry/sentry-powershell/pull/71), [#78](https://github.com/getsentry/sentry-powershell/pull/78), [#79](https://github.com/getsentry/sentry-powershell/pull/79))
  - [changelog](https://github.com/getsentry/sentry-dotnet/blob/main/CHANGELOG.md#540)
  - [diff](https://github.com/getsentry/sentry-dotnet/compare/4.13.0...5.4.0)

## 0.2.1

### Fixes

- Capture doesn't work if `-Debug` wasn't set ([#74](https://github.com/getsentry/sentry-powershell/pull/74))
- Don't log debug messages if `-Debug` wasn't set ([#75](https://github.com/getsentry/sentry-powershell/pull/75))

### Dependencies

- Bump Dotnet SDK from v4.12.1 to v4.13.0 ([#69](https://github.com/getsentry/sentry-powershell/pull/69))
  - [changelog](https://github.com/getsentry/sentry-dotnet/blob/main/CHANGELOG.md#4130)
  - [diff](https://github.com/getsentry/sentry-dotnet/compare/4.12.1...4.13.0)

## 0.2.0

### Features

- Send events to Sentry fully synchronously ([#59](https://github.com/SummitHosting/sentry-powershell/pull/59), [#62](https://github.com/SummitHosting/sentry-powershell/pull/62))
- Add StackTrace context to frames coming from inline script/command ([#65](https://github.com/getsentry/sentry-powershell/pull/65))

### Fixes

- StackTrace parsing on Windows PowerShell 5.1 ([#50](https://github.com/getsentry/sentry-powershell/pull/50))
- Fix out of bounds context for short scripts ([#58](https://github.com/getsentry/sentry-powershell/pull/58))
- Windows PowerShell needs both unsafe 4.5.3 and 6.0.0 dll ([#61](https://github.com/getsentry/sentry-powershell/pull/61))

### Dependencies

- Bump Dotnet SDK from v4.4.0 to v4.12.1 ([#47](https://github.com/getsentry/sentry-powershell/pull/47), [#51](https://github.com/getsentry/sentry-powershell/pull/51), [#52](https://github.com/getsentry/sentry-powershell/pull/52), [#53](https://github.com/getsentry/sentry-powershell/pull/53), [#54](https://github.com/getsentry/sentry-powershell/pull/54), [#57](https://github.com/getsentry/sentry-powershell/pull/57))
  - [changelog](https://github.com/getsentry/sentry-dotnet/blob/main/CHANGELOG.md#4121)
  - [diff](https://github.com/getsentry/sentry-dotnet/compare/4.4.0...4.12.1)

## 0.1.0

### Features

- Send events synchronously so they're not lost when the script exits ([#39](https://github.com/getsentry/sentry-powershell/pull/39))

### Fixes

- Transaction sampling ([#38](https://github.com/getsentry/sentry-powershell/pull/41))

### Dependencies

- Bump Dotnet SDK from v4.1.2 to v4.4.0 ([#44](https://github.com/getsentry/sentry-powershell/pull/44), [#45](https://github.com/getsentry/sentry-powershell/pull/45))
  - [changelog](https://github.com/getsentry/sentry-dotnet/blob/main/CHANGELOG.md#440)
  - [diff](https://github.com/getsentry/sentry-dotnet/compare/4.1.2...4.4.0)

## 0.0.2

### Various fixes & improvements

- add changelog (c5bcf218) by @vaind
- chore: use env file to change craft log level (4431f857) by @vaind
- chore: change craft log level to trace (77ffea0c) by @vaind
- docs: add sentry psgallery link (bd550ba5) by @vaind
- fixup psd links (9b04cf8a) by @vaind

## 0.0.1

Initial manual release of the PowerShell Sentry SDK.
