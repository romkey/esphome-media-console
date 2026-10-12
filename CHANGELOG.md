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
