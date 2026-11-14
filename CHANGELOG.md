# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Media console package (`packages/media-console.yaml`): album art, track
  info, progress, transport, shuffle, repeat, mute and volume for a Home
  Assistant media player, with idle dimming.
- Example device for the Hosyond 4" ESP32-32E (resistive touch), plus
  ESP32-C3 and ESP32-S3 examples with an SPI ST7796 panel and FT6336 touch.
- Shared base config: encrypted API and OTA, fallback hotspot, safe mode and
  factory reset buttons, password-protected web server, esphome-lib
  diagnostics.
- Docker Compose services, pre-commit lint, CI with cached builds and a
  weekly ESPHome beta build, release workflow, Renovate.
- Examples load their shared config and the package from GitHub, so a single
  example file builds on its own in any ESPHome install; `*-local.yaml`
  copies build from the checkout instead, and CI builds those.
- Header with the player name, a clock and Wi-Fi / Home Assistant status
  icons; the center says "WiFi Disconnected" or "Home Assistant
  Disconnected" instead of "Nothing playing" when a connection is down.
  New substitutions `media_console_player_name`, `media_console_time_format`,
  `media_console_ok_color` and `media_console_error_color`.
- "Idle Dimming" switch in Home Assistant to turn the idle backlight dimming
  off; on by default and remembered across restarts.

### Changed

- Remote packages in the examples use the long form with `refresh: 0s`, so
  every build fetches the latest `main` instead of a copy cached for a day.

### Fixed

- The center message started as "Nothing playing" while the header icons
  showed Wi-Fi and Home Assistant disconnected, until the first status
  refresh a second later. It now starts as "WiFi Disconnected".
- Idle dimming made the screen look switched off: the example backlights
  used the default gamma of 2.8, which turned the 15% dim level into about
  0.5% PWM duty. They now set `gamma_correct: 1.0`.
