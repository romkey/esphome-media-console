# Instructions for AI assistants

Follow https://github.com/romkey/esphome-ai-coding-rules/blob/main/RULES.md.
With Claude Code, the `esphome-rules` plugin loads them for you.

Read docs/overview.md first. `main` is protected: work on a branch and
open a pull request; CI and Lint must pass before it can merge.

<!-- Project-specific notes go below. -->

- The Hosyond board has no PSRAM: watch RAM when touching LVGL buffers or
  album art size, and never add TLS to the album art fetch.
- PLAN.md records the original design and what still needs testing on
  hardware.
