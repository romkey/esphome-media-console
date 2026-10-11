# Plan: ESPHome Media Console for the Hosyond 4" CYD

Status: **implemented (v1), compiles; untested on hardware.** Deviations: display orientation uses the panel `transform` (LVGL rejects display `rotation`); `streaming_jpeg_image` not built.

> **Layout changed since this plan:** the repo now follows
> [esphome-ai-coding-rules](https://github.com/romkey/esphome-ai-coding-rules/blob/main/RULES.md).
> The package is `packages/media-console.yaml` (substitutions prefixed
> `media_console_`), board and pins live in `examples/`, and secrets come from
> `examples/secrets.yaml`. Paths and tooling below (`src/`, `local.yaml`,
> `docker-compose.yml`, `ci.yml`/`lint.yml`) describe the original layout.

## 1. Goal

ESPHome firmware for the Hosyond 4.0" ESP32-32E "Cheap Yellow Display" that
shows a landscape media console for a Home Assistant `media_player`: album art,
track info, progress, and transport/volume controls, built with LVGL.

The media console is a reusable ESPHome package that is independent of the
board definition, so it can be dropped into other ESPHome projects with a
display and touchscreen.

Players to optimize for, in priority order:

1. **Music Assistant** players
2. **AirPlay**, via Music Assistant's AirPlay provider
3. **Spotify Connect**, best effort

## 2. Hardware

### 2.1 Board pins (to verify on the real board)

| Function            | GPIO           | Notes                                 |
|---------------------|----------------|---------------------------------------|
| LCD SPI SCK         | 14             |                                       |
| LCD SPI MOSI        | 13             |                                       |
| LCD SPI MISO        | 12             |                                       |
| LCD CS              | 15             |                                       |
| LCD DC              | 2              |                                       |
| LCD RST             | tied to EN     | No reset pin in config                |
| Backlight           | 27             | LEDC PWM → dimmable                   |
| RGB LED             | 22 / 16 / 17   | Active low; optional status indicator |
| Audio, SD, battery  | 4/26, 5/18/23/19, 34 | Not used in v1                  |

- MCU: ESP32-WROOM-32E, **no PSRAM** — the main constraint on the design.
- Panel: ST7796, 320×480 native portrait; run rotated 90° for 480×320 landscape.

### 2.2 Touch

v1 targets the **resistive** variant (LCDWiki E32R40T): an XPT2046 on the SPI
bus shared with the LCD, CS 33, IRQ 36.

A capacitive (FT6336U, I²C) variant is deferred until its pins are known. The
board layout keeps touch in its own file, so adding it later means adding one
`touch-capacitive.yaml` and one top-level config.

## 3. Repository layout

```
.
├── README.md
├── LICENSE                    # MIT, Copyright (c) 2026 John Romkey
├── PLAN.md
├── docker-compose.yml
├── .gitignore                 # src/local*, .esphome build dirs, etc.
├── .yamllint
├── .github/workflows/
│   ├── ci.yml                 # compiles the device + a reuse example
│   └── lint.yml               # yamllint + `esphome config`
└── src/
    ├── hosyond-4in-resistive.yaml     # top-level device config
    ├── example-local.yaml             # template → copy to src/local.yaml
    ├── boards/hosyond-esp32-32e-4in/
    │   ├── base.yaml                  # ESP32, SPI, ST7796, backlight, RGB LED
    │   └── touch-resistive.yaml       # XPT2046 + calibration
    │                                  # (touch-capacitive.yaml later)
    └── media_console/
        ├── media_console.yaml         # reusable media console package
        └── components/                # only if the album art spike needs it (§5.3)
            └── streaming_jpeg_image/
```

`src/local.yaml` (gitignored by `src/local*`) holds per-install settings:
Wi-Fi, API encryption key, OTA password, `media_player` entity id, and
`ha_base_url`. CI copies `example-local.yaml` to `local.yaml` before building.

## 4. Separation of concerns

### 4.1 Board definition: `src/boards/hosyond-esp32-32e-4in/`

Hardware only. `base.yaml` plus one `touch-*.yaml` (only the resistive one
exists in v1).

- **`base.yaml`**
  - `esp32:` board `esp32dev`, framework `esp-idf`.
  - `spi:` bus.
  - `display:` `mipi_spi` model ST7796 (fallback `ili9xxx`), `rotation: 90`,
    `update_interval: never` (LVGL drives it), id `board_display`.
  - LEDC backlight as `light:` `board_backlight`.
  - Optional RGB status LED.
- **`touch-resistive.yaml`**: `xpt2046` on the shared SPI bus, with
  calibration substitutions and a `transform` for landscape.

Every touch file uses the touchscreen id `board_touch`, so nothing downstream
needs to know which one is in use.

### 4.2 Media console package: `src/media_console/media_console.yaml`

Included with `!include` and `vars`, or remotely as
`github://romkey/esphome-media-console/src/media_console/media_console.yaml@<tag>`.

**What the host config must provide:** one `display`, one `touchscreen`,
`wifi`, and `api`. If the host already uses LVGL, the console's page
(`id: media_console_page`) merges into the host's `lvgl: pages:`.

**Package vars:**

| Var                | Example                           | Purpose                                     |
|--------------------|-----------------------------------|---------------------------------------------|
| `media_player`     | `media_player.living_room`        | Required.                                   |
| `ha_base_url`      | `http://homeassistant.local:8123` | Required. Prefix for relative art paths.    |
| `art_size`         | `180`                             | Album art edge in px.                       |
| `backlight_id`     | `board_backlight`                 | For idle dimming (optional).                |
| `idle_dim_timeout` | `60s`                             |                                             |
| `accent_color`     | `0x4FC3F7`                        | UI accent (not red).                        |

**What the package contains:**

- `homeassistant` sensors for: state, `media_title`, `media_artist`,
  `media_album_name`, `entity_picture`, `entity_picture_local`,
  `media_duration`, `media_position`, `volume_level`, `is_volume_muted`,
  `shuffle`, `repeat`, `friendly_name`.
- LVGL page (§6), `homeassistant.action` scripts for the controls, local
  progress interpolation (stores the reported position plus `millis()`; a 1 s
  `interval:` advances it while playing), and idle dim/wake.
- Album art pipeline (§5).

## 5. Album art without PSRAM and without extra infrastructure

There will be **no** sidecar or helper service. Everything happens either on
the device or through URLs the user's existing HA or Music Assistant already
serves. The approach has three layers, applied in order:

### 5.1 Ask the source for a small image (most important for MA)

The art URL is built in a lambda from `entity_picture_local`, falling back to
`entity_picture`:

- **Music Assistant** players expose art through the MA server's
  `/imageproxy?...&size=N` endpoint, which resizes on the server side. If the
  URL is an MA imageproxy URL, the lambda rewrites or adds `size=${art_size}`
  so the device downloads a small, roughly 10–20 KB image. *To verify:* the
  exact URL shape the MA → HA integration puts in the entity attributes, and
  whether it's reachable over plain HTTP from the device.
- **AirPlay** players come in through Music Assistant's AirPlay provider, so
  they use the same MA path and are covered by the item above.
- Other HA-proxied players get a relative `/api/media_player_proxy/...` URL.
  The lambda prefixes it with `ha_base_url`. The image comes back at source
  size, which the next layer handles.
- **Spotify Connect:** `entity_picture` is an external HTTPS 640 px URL, so the
  lambda uses `entity_picture_local` instead. That's the HA proxy over plain
  HTTP, which avoids TLS on the device. The image is still 640 px, which the
  next layer also handles.

### 5.2 Decode on the device, in pieces (only if needed)

With MA covering both of the main player types, this layer only matters for
Spotify Connect and other HA-proxied players. It's built only if the spike
shows it's needed, and it can slip to after v1.

Stock `online_image` buffers the whole downloaded file before decoding. That's
fine for MA-sized images but risky for 50–150 KB JPEGs on a board with no
PSRAM. The spike (step 8.3) measures the real limit. If stock `online_image`
fails at realistic sizes, the plan adds a small external component,
`streaming_jpeg_image`:

- It streams the HTTP body through a small ring buffer (about 4–8 KB) into
  JPEGDEC's callback decoder.
- It uses JPEGDEC's built-in 1/2, 1/4, or 1/8 scaling, picking the factor so
  the result is at least `art_size`, then box-scales to the final size.
- Its output is one RGB565 `art_size`² buffer (about 65 KB at 180 px), exposed
  as an ESPHome `image` that LVGL can show.
- It keeps the same YAML surface as `online_image` (`url`, `on_download_finished`,
  `on_error`), so switching between the two only changes the YAML.

### 5.3 Fail gracefully

Unsupported images (progressive JPEG, or PNG too large to decode) and timeouts
show the placeholder, and the reason is logged. A diagnostic text sensor
reports the last art error and free heap, so users can report problems without
a serial cable.

## 6. UI layout (480×320 landscape)

```
┌──────────────────────────────────────────────────────────┐
│ ♪ Living Room                                     ● wifi │  top bar
├──────────────────┬───────────────────────────────────────┤
│                  │ Song Title (large, scrolls if long)   │
│    Album Art     │ Artist                                │
│     180×180      │ Album (dim)                           │
│                  │ ━━━━━━━━━━━━●────────────  1:42 / 3:58  │
│                  │   ⇄     ⏮     ⏯     ⏭     🔁         │
├──────────────────┴───────────────────────────────────────┤
│ 🔈  ━━━━━━━━━━━━━━━━━━━━━━━━━━━●─────────────   🔇        │
└──────────────────────────────────────────────────────────┘
```

- Built-in `LV_SYMBOL_*` icons. Roboto font with Latin-extended glyphs; CJK
  isn't supported in v1, which the README documents.
- Flex and percentage sizing, so the same package works on 320×240.
- Touch targets are at least 48 px, which matters for the resistive variant.
- The volume slider ignores HA updates while being dragged and sends
  `volume_set` on release.
- Idle/off/unavailable states show a "Nothing playing" screen. The first touch
  after dimming only wakes the screen and isn't passed through as a press.
- Dark theme. No red in the palette except actual error states.

## 7. Tooling

### 7.1 `docker-compose.yml`

- `esphome` service, pinned `ghcr.io/esphome/esphome:<version>`, mounting
  `./src:/config`, with a named volume for the PlatformIO cache.
- The default command compiles `hosyond-4in-resistive.yaml`. The `CONFIG`
  environment variable overrides it, so new variants need no compose changes.

- Optional `dashboard` service under a profile, on port 6052.
- README note: the first flash is the factory `.bin` via web.esphome.io
  (Docker on macOS has no USB passthrough), then OTA after that.

### 7.2 `.gitignore`

`src/local*`, `src/.esphome/`, `**/.pioenvs/`, `**/.piolibdeps/`,
`src/secrets.yaml`, `.DS_Store`.

### 7.3 GitHub Actions

- `lint.yml`: yamllint (with ESPHome tags allowed), then `esphome config` for
  each top-level config.
- `ci.yml`: matrix build (the resistive device config, plus a minimal
  "package only" host that checks reusability). Firmware binaries are uploaded as artifacts.

### 7.4 README badges (no red static colors)

- CI and Lint: GitHub workflow status badges for
  `romkey/esphome-media-console`. These are dynamic and show red only on a real
  failure.
- ESPHome: shields.io, `logo=esphome`, color `18BCF2`, showing the pinned
  version.
- License: shields.io `MIT`, blue.

## 8. Implementation steps

1. Scaffold the repo: layout, `.gitignore`, LICENSE (John Romkey), compose
   file, `example-local.yaml`, and a README with badges.
2. **Hardware bring-up:** `base.yaml` plus `touch-resistive.yaml`, with a test
   page that logs touches. Confirm rotation, colors, backlight, and touch
   calibration.
3. **Album art spike:** with real MA players (including AirPlay through MA),
   plus Spotify as a secondary check:
   - Record the actual `entity_picture` and `entity_picture_local` values.
   - Confirm the MA `size=` rewrite works.
   - Measure stock `online_image` against free heap.
   - Decide whether `streaming_jpeg_image` (§5.2) is needed.
4. Media console package: sensors, then static layout, then data binding, then
   controls, then progress interpolation, then idle dimming.
5. Build `streaming_jpeg_image` if step 3 shows it's needed (can come after v1).
6. Write the top-level device config and test end-to-end.
7. Write the minimal reuse example and add the CI/lint workflows.
8. README:
   - Quick start.
   - The HA option "Allow the device to perform Home Assistant actions".
   - Reusing the package.
   - Per-player album art notes.
   - Known limitations.

## 9. Risks and mitigations

| Risk | Mitigation |
|------|------------|
| Full-size JPEGs don't fit in RAM. | Ask MA for a small image (§5.1), stream and scale on the device (§5.2), fall back to the placeholder (§5.3). |
| The MA art URL shape isn't what's expected, or it isn't reachable over HTTP. | Step 3 checks it. The fallback is the HA proxy path plus streaming decode. |
| Progressive JPEGs (some Spotify and AirPlay sources). | JPEGDEC only partially supports them. Show the placeholder and log it. Spotify is the lowest priority. |
| Heap pressure from LVGL, Wi-Fi, and the art buffer together. | LVGL `buffer_size` around 12–25%, art at 180 px or smaller, no TLS, and a heap diagnostic sensor. |
| HA blocks device actions by default. | Document the HA option, and show a hint on screen when an action fails. |
| `mipi_spi` quirks with this ST7796 panel. | Fall back to `ili9xxx`. |

## 10. Out of scope for v1

- Choosing or swiping between players at runtime.
- Browsing media and queues.
- Using the onboard speaker or SD card.
- Building colors from the album art.
- The capacitive touch variant (deferred until its pins are known).
- Board files for other CYD sizes.

## 11. Decisions

- Repo `romkey/esphome-media-console`; license MIT, John Romkey.
- Resistive touch only in v1; capacitive deferred.
- AirPlay through Music Assistant, so MA's server-side resizing is the main
  album art path.
- No extra infrastructure (sidecars or helper services) required of users.
