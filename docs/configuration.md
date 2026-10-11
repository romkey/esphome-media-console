# Configuration

## `packages/media-console.yaml`

A landscape LVGL media console for one Home Assistant `media_player`: album
art, title, artist, album, progress, transport, shuffle, repeat, mute and
volume, with idle dimming. Include it once per device.

**Requires:** one `display` and one `touchscreen` (480×320 landscape), `wifi`,
`api`, and a dimmable `light` whose id is `media_console_backlight_id`. In
Home Assistant, enable **Allow the device to perform Home Assistant actions**
for the device.

**Defines:** `http_request`, `online_image`, `font`, `lvgl`, `globals`,
`script`, `interval`, Home Assistant mirror sensors (all `internal`), and
ids starting with `mc_`. A host that already uses LVGL gets the console's
page (`media_console_page`) merged into its `lvgl: pages:`.

| Substitution | Default | Meaning |
|--------------|---------|---------|
| `media_console_media_player` | (required) | Entity to show and control, e.g. `media_player.living_room` |
| `media_console_ha_base_url` | (required) | Home Assistant URL, prefixed to relative album art paths. Use plain `http://` |
| `media_console_backlight_id` | (required) | Id of a dimmable `light`, for idle dimming |
| `media_console_art_size` | `180` | Album art edge in px. RAM used: size² × 2 bytes |
| `media_console_idle_dim_timeout` | `60s` | Dim the screen after this long without a touch |
| `media_console_idle_dim_brightness` | `15%` | Brightness while dimmed |
| `media_console_accent_color` | `0x4FC3F7` | UI accent color (progress, volume, active toggles) |
| `media_console_art_status_name` | `Album Art Status` | Name of the diagnostic text sensor reporting album art problems |

The first touch after dimming only wakes the screen. The volume slider sends
`volume_set` on release and ignores Home Assistant updates while dragged.

```yaml
substitutions:
  media_console_media_player: media_player.living_room
  media_console_ha_base_url: http://homeassistant.local:8123
  media_console_backlight_id: backlight

packages:
  media_console: github://romkey/esphome-media-console/packages/media-console.yaml@v0.1.0
```

## Hosyond board substitutions

Set in [`examples/hosyond-4in-resistive.yaml`](../examples/hosyond-4in-resistive.yaml)
(or your `examples/local-*.yaml` copy of it):

| Substitution | Default | Meaning |
|--------------|---------|---------|
| `board_mirror_x`, `board_mirror_y` | `true`, `false` | Panel mirroring; flip if the picture is mirrored or upside down |
| `board_color_order` | `bgr` | `rgb` if red and blue are swapped |
| `board_invert_colors` | `false` | `true` if colors look inverted |
| `touch_x_min`, `touch_x_max`, `touch_y_min`, `touch_y_max` | `300`, `3800`, `300`, `3800` | XPT2046 raw calibration range |
