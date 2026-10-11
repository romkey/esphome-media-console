# ESPHome Media Console overview

**What:** a touchscreen LVGL media console for a Home Assistant `media_player`.
**Kind:** app (one board-agnostic UI package plus device configs); no
published firmware, since each build names its media player.
**Hardware:** Hosyond 4" ESP32-32E (LCDWiki E32R40T): ESP32-WROOM-32E, 4 MB
flash, no PSRAM, ST7796 480×320 SPI panel, XPT2046 resistive touch. C3/S3
examples use an SPI ST7796 + FT6336 touch on I2C (`i2c0`, address 0x38).

## Files

- `packages/media-console.yaml`: HA mirror sensors, album art pipeline
  (`online_image`, JPEG, resized), LVGL page, control scripts, idle dimming.
- `examples/hosyond-4in-resistive.yaml`: the target device; board + pins.
- `examples/esp32-c3.yaml`, `examples/esp32-s3.yaml`: generic boards, CI
  proof that the package is board-agnostic.
- `examples/common/base.yaml`: shared project, network and recovery config.
- `PLAN.md`: original design and open hardware questions.

## Required by packages

- Substitutions: `media_console_media_player`, `media_console_ha_base_url`,
  `media_console_backlight_id`.
- One `display`, one `touchscreen`, a dimmable `light`, `wifi`, `api`.

## Conventions

- Substitutions prefixed `media_console_`; internal ids prefixed `mc_`.
- Package included once per device (single LVGL page).
- Album art is fetched over plain HTTP only (no TLS without PSRAM).
- Personal device configs: `examples/local-*.yaml` (gitignored).
- Rules: https://github.com/romkey/esphome-ai-coding-rules/blob/main/RULES.md
