# ESPHome Media Console

[![CI](https://github.com/romkey/esphome-media-console/actions/workflows/ci.yml/badge.svg)](https://github.com/romkey/esphome-media-console/actions/workflows/ci.yml)
[![Lint](https://github.com/romkey/esphome-media-console/actions/workflows/lint.yml/badge.svg)](https://github.com/romkey/esphome-media-console/actions/workflows/lint.yml)
[![ESPHome](https://img.shields.io/badge/ESPHome-2026.7.4-18BCF2?logo=esphome&logoColor=white)](https://esphome.io)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A touchscreen media console for Home Assistant, built with ESPHome and LVGL.
It shows what's playing on a `media_player` — album art, title, artist, album,
progress — with play/pause, previous/next, shuffle, repeat, mute and volume
controls. It runs in landscape on the **Hosyond 4" ESP32-32E "CYD"** (480×320).

The console is a self-contained ESPHome package, kept separate from the board
definition, so you can drop it into your own project with a different display.

Works best with **Music Assistant** players (including AirPlay players exposed
through Music Assistant). Spotify Connect players work too, with caveats (see
[Album art](#album-art)).

## Repository layout

```
src/
├── hosyond-4in-resistive.yaml      # the device: board + media console
├── example-local.yaml              # copy to src/local.yaml
├── boards/hosyond-esp32-32e-4in/   # board definition (hardware only)
│   ├── base.yaml                   #   ESP32, SPI, ST7796 display, backlight
│   └── touch-resistive.yaml        #   XPT2046 touch
├── media_console/
│   └── media_console.yaml          # the reusable media console package
└── examples/standalone-host.yaml   # the console on a different board
```

## Quick start

You need Docker and a Home Assistant instance.

1. Create your local settings (this file is gitignored):

   ```bash
   cp src/example-local.yaml src/local.yaml
   ```

   Edit it: Wi-Fi credentials, a fresh API encryption key
   (`openssl rand -base64 32`), an OTA password, your `media_player` entity,
   and `ha_base_url` (use plain `http://` on your LAN; see [Album art](#album-art)).

2. Build:

   ```bash
   docker compose run --rm esphome
   ```

   The firmware lands in `build/media-console/`.

3. Flash. Docker Desktop on macOS can't pass USB through, so for the first
   flash upload `build/media-console/firmware.factory.bin` with
   <https://web.esphome.io> (Chrome/Edge). After that, update over the air
   from the ESPHome dashboard (`docker compose --profile dashboard up dashboard`,
   then open <http://localhost:6052>).

4. In Home Assistant, add the device, then open its settings and enable
   **Allow the device to perform Home Assistant actions**. Without this, the
   buttons do nothing.

To build a different config: `CONFIG=examples/standalone-host.yaml docker compose run --rm esphome`.

## Using the media console in your own project

Your config must provide one `display`, one `touchscreen`, `wifi`, `api`, and a
dimmable `light` for the backlight. Then include the package:

```yaml
packages:
  media_console: !include
    file: media_console/media_console.yaml
    vars:
      media_player: media_player.living_room
      ha_base_url: http://homeassistant.local:8123
      backlight_id: my_backlight
```

or pull it straight from GitHub:

```yaml
packages:
  media_console:
    url: https://github.com/romkey/esphome-media-console
    ref: main
    files: [src/media_console/media_console.yaml]
    vars:
      media_player: media_player.living_room
      ha_base_url: http://homeassistant.local:8123
      backlight_id: my_backlight
```

| Variable              | Default     | Meaning                                              |
|-----------------------|-------------|------------------------------------------------------|
| `media_player`        | *required*  | Entity to show and control                           |
| `ha_base_url`         | *required*  | Home Assistant URL, used for album art               |
| `backlight_id`        | *required*  | Id of a dimmable `light` (for idle dimming)          |
| `art_size`            | `180`       | Album art size in px (RAM: size² × 2 bytes)          |
| `idle_dim_timeout`    | `60s`       | Dim the screen after this long without a touch       |
| `idle_dim_brightness` | `15%`       | Brightness while dimmed                              |
| `accent_color`        | `0x4FC3F7`  | UI accent color                                      |

The layout is designed for **480×320** landscape. The package also defines
`http_request`, `online_image`, `font` and `lvgl`, so a host that already uses
those needs to reconcile them. See [src/examples/standalone-host.yaml](src/examples/standalone-host.yaml)
for a complete host with its own board definition.

## Album art

The board has no PSRAM, so it never downloads a full-size cover. The console
picks a URL from the player's attributes and fetches it over plain HTTP:

- **Music Assistant** (and AirPlay through it): Music Assistant's image proxy
  resizes on the server, so the console asks it for `art_size` pixels as JPEG
  and downloads a small image.
- **Other players**: Home Assistant's proxied image is fetched as is and shrunk
  while decoding. Large or progressive JPEGs (common with Spotify) may not
  decode; the placeholder is shown and the reason appears in the
  **Album Art Status** diagnostic sensor.

Only JPEG is decoded. Text uses a Latin character set, so CJK titles won't render.

## Board notes (Hosyond 4" ESP32-32E)

Pins follow the [LCDWiki E32R40T documentation](https://www.lcdwiki.com/4.0inch_ESP32-32E_Display):
SPI on GPIO14/13/12, LCD CS 15, DC 2, backlight 27, touch CS 33, touch IRQ 36.

This is the **resistive** touch variant. A capacitive variant isn't supported
yet.

- **Colors wrong?** Set `board_color_order` or `board_invert_colors` in the substitutions of your
  `src/local.yaml` substitutions.
- **Picture mirrored/upside down?** Flip `board_mirror_x` / `board_mirror_y`
  (and match the `transform` in `touch-resistive.yaml`).
- **Touch calibration.** Touches that land in the wrong place mean the raw
  range is off. Set `logger: level: VERY_VERBOSE`, watch the xpt2046 raw
  values while touching the corners, and set `touch_x_min`, `touch_x_max`,
  `touch_y_min`, `touch_y_max` in `src/local.yaml`.

## Development

CI builds every config in `src/` and lints the YAML:

```bash
yamllint -c .yamllint .
docker compose run --rm --entrypoint esphome esphome config hosyond-4in-resistive.yaml
```

## License

[MIT](LICENSE) © 2026 John Romkey
