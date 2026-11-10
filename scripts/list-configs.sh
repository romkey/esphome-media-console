#!/bin/sh
# Prints every buildable ESPHome config, one per line: examples/ and, for
# projects that publish firmware, firmware/. CI, the release workflow and
# compose.yaml all use this so the list lives in one place.
#
#   scripts/list-configs.sh              # examples/ and firmware/
#   scripts/list-configs.sh firmware     # just firmware/
#   scripts/list-configs.sh --json ...   # as a JSON array (needs jq), for
#                                        # GitHub Actions matrices
#
# Accepts .yaml and .yml; skips secrets, personal local* configs and
# subdirectories such as examples/common/. Also skips foo.yaml when a
# foo-local.yaml sits next to it: foo.yaml pulls its includes from GitHub, so
# building it would test main, not this checkout; foo-local.yaml is the same
# config using local files.
cd "$(dirname "$0")/.." || exit 1
json=false
if [ "${1:-}" = --json ]; then json=true; shift; fi
[ $# -gt 0 ] || set -- examples firmware
for dir in "$@"; do
  [ -d "$dir" ] || continue
  find "$dir" -maxdepth 1 -type f \( -name '*.yaml' -o -name '*.yml' \) \
    ! -name 'secrets.*' ! -name 'local*'
done | while read -r file; do
  base=${file%.*}
  [ -e "$base-local.yaml" ] || [ -e "$base-local.yml" ] || echo "$file"
done | sort | if $json; then jq -Rsc 'split("\n") | map(select(. != ""))'; else cat; fi
