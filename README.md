# ESPHome Media Console

[![CI](https://github.com/romkey/esphome-media-console/actions/workflows/ci.yaml/badge.svg)](https://github.com/romkey/esphome-media-console/actions/workflows/ci.yaml)
[![Lint](https://github.com/romkey/esphome-media-console/actions/workflows/lint.yaml/badge.svg)](https://github.com/romkey/esphome-media-console/actions/workflows/lint.yaml)
[![ESPHome](https://img.shields.io/badge/ESPHome-packages-18BCF2?logo=esphome&logoColor=white)](https://esphome.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A touchscreen media console for Home Assistant, built with ESPHome and LVGL.
It shows what's playing on a `media_player` (album art, title, artist, album,
progress) with play/pause, previous/next, shuffle, repeat, mute and volume
controls. It's built for the **Hosyond 4" ESP32-32E "CYD"** (480×320,
landscape), and the console is a board-agnostic package you can drop into
your own project with a different display. Works best with **Music
Assistant** players (including AirPlay players exposed through Music
Assistant); Spotify Connect players work too, with caveats (see
[Album art](#album-art)).

> **AI disclosure:** This project was written by AI under human oversight,
> following [these rules](https://github.com/romkey/esphome-ai-coding-rules/blob/main/RULES.md).

## What's here

| Path | What it is |
|------|------------|
| [`packages/media-console.yaml`](packages/media-console.yaml) | The media console: Home Assistant state, album art, LVGL UI, controls, idle dimming |
| [`examples/hosyond-4in-resistive.yaml`](examples/hosyond-4in-resistive.yaml) | The Hosyond 4" ESP32-32E (resistive touch): the device this project is for |
| [`examples/esp32-c3.yaml`](examples/esp32-c3.yaml), [`examples/esp32-s3.yaml`](examples/esp32-s3.yaml) | The console on an ESP32-C3 / ESP32-S3 dev kit with an SPI ST7796 panel and FT6336 touch; prove the package is board-agnostic |
| [`examples/common/base.yaml`](examples/common/base.yaml) | Shared: project version, Wi-Fi, encrypted API/OTA, recovery, web server, diagnostics |
| [`docs/configuration.md`](docs/configuration.md) | Every substitution, with defaults |
| [`PLAN.md`](PLAN.md) | The original design plan and its open questions |

## Technical details

### Hosyond 4" ESP32-32E (LCDWiki E32R40T)

ESP32-WROOM-32E with 4 MB flash and **no PSRAM**, an ST7796 320×480 panel run
as 480×320 landscape, and an XPT2046 resistive touch controller sharing the
LCD's SPI bus. Pins per the
[LCDWiki documentation](https://www.lcdwiki.com/4.0inch_ESP32-32E_Display):

| Function | GPIO |
|----------|------|
| SPI SCK / MOSI / MISO | 14 / 13 / 12 |
| LCD CS / DC | 15 / 2 (RST is tied to EN) |
| Backlight (PWM, high = on) | 27 |
| Touch CS / IRQ | 33 / 36 |

This is the **resistive** touch variant. A capacitive variant isn't
supported yet.

- **Colors wrong?** Set `board_color_order` or `board_invert_colors`.
- **Picture mirrored/upside down?** Flip `board_mirror_x` / `board_mirror_y`
  (and match the touchscreen `transform`).
- **Touch calibration.** Touches that land in the wrong place mean the raw
  range is off. Set `logger: level: VERY_VERBOSE`, watch the xpt2046 raw
  values while touching the corners, and set `touch_x_min`, `touch_x_max`,
  `touch_y_min`, `touch_y_max`.

### ESP32-C3 and ESP32-S3 examples

A generic SPI ST7796 480×320 panel with an FT6336 capacitive touch controller
on I2C (`i2c0`); wiring is in the comments at the top of each file. These
compile in CI; they have not been tried on hardware.

### Album art

The Hosyond board has no PSRAM, so the console never downloads a full-size
cover. It picks a URL from the player's attributes and fetches it over plain
HTTP:

- **Music Assistant** (and AirPlay through it): Music Assistant's image proxy
  resizes on the server, so the console asks it for `media_console_art_size`
  pixels as JPEG and downloads a small image.
- **Other players**: Home Assistant's proxied image is fetched as is and
  shrunk while decoding. Large or progressive JPEGs (common with Spotify) may
  not decode; the placeholder is shown and the reason appears in the
  **Album Art Status** diagnostic sensor.

Only JPEG is decoded. Text uses a Latin character set, so CJK titles won't
render.

## Build and use

You need Docker and a Home Assistant instance.

1. Secrets (gitignored):

   ```bash
   cp examples/secrets.yaml.example examples/secrets.yaml
   ```

   Edit it: Wi-Fi, a fresh API encryption key (`openssl rand -base64 32`),
   a fallback hotspot password and web server login.

2. Your device config (also gitignored):

   ```bash
   cp examples/hosyond-4in-resistive.yaml examples/local-living-room.yaml
   ```

   Set `name`, `media_console_media_player` and `media_console_ha_base_url`
   (plain `http://` on your LAN; see [Album art](#album-art)).

3. Build and flash. Docker Desktop on macOS can't pass USB through, so the
   first flash goes through <https://web.esphome.io> (Chrome/Edge). Compile,
   then copy the factory image out of the build volume; replace
   `media-console` with the `name:` you set:

   ```bash
   docker compose run --rm esphome compile examples/local-living-room.yaml
   docker compose run --rm --entrypoint sh esphome -c 'cp "$(find /build/media-console -name firmware.factory.bin)" /project/'
   ```

   Upload `firmware.factory.bin` (now in the repo root, gitignored) with
   web.esphome.io. Or use the dashboard, `docker compose up dashboard`, then
   <http://localhost:6052>: **Install → Manual download → Factory format**.

   After that, update over the air:

   ```bash
   docker compose run --rm esphome run examples/local-living-room.yaml
   ```

4. In Home Assistant, add the device, then open its settings and enable
   **Allow the device to perform Home Assistant actions**. Without this, the
   buttons do nothing.

### Using the package in your own config

Your config must provide one `display`, one `touchscreen`, `wifi`, `api`, and
a dimmable `light` for the backlight:

```yaml
substitutions:
  media_console_media_player: media_player.living_room
  media_console_ha_base_url: http://homeassistant.local:8123
  media_console_backlight_id: my_backlight

packages:
  media_console: github://romkey/esphome-media-console/packages/media-console.yaml@v0.1.0
```

The layout is designed for **480×320** landscape. The package also defines
`http_request`, `online_image`, `font` and `lvgl`, so a host that already
uses those needs to reconcile them. See
[docs/configuration.md](docs/configuration.md) for every option.

### Development

```bash
docker compose run --rm validate   # esphome config on every example
docker compose run --rm build      # compile every example, like CI
docker compose run --rm lint       # all pre-commit checks, like CI
```

## License

[MIT](LICENSE)
