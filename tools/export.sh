#!/usr/bin/env bash
# Exports the game into build/<platform>/ using the presets in export_presets.cfg.
# Used by the GitHub workflows and handy locally too.
#
# Usage:  tools/export.sh [web|windows|linux|macos|all]...   (default: web)
# Uses $GODOT if set, otherwise `godot` from the PATH. Export templates must be
# installed (Editor > Manage Export Templates).
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT=${GODOT:-godot}
targets=("$@")
if [ ${#targets[@]} -eq 0 ]; then
    targets=(web)
elif [[ " ${targets[*]} " == *" all "* ]]; then
    targets=(web windows linux macos)
fi

# Make sure imported resources are up to date (first run on a fresh clone).
"$GODOT" --headless --path . --import > /dev/null

for target in "${targets[@]}"; do
    case "$target" in
        web)     preset="Web";     output="build/web/index.html" ;;
        windows) preset="Windows"; output="build/windows/MaxPain.exe" ;;
        linux)   preset="Linux";   output="build/linux/MaxPain.x86_64" ;;
        macos)   preset="macOS";   output="build/macos/MaxPain.zip" ;;
        *) echo "Unknown target: $target" >&2; exit 1 ;;
    esac
    rm -rf "$(dirname "$output")"
    mkdir -p "$(dirname "$output")"
    echo "Exporting $preset -> $output"
    "$GODOT" --headless --path . --export-release "$preset" "$output"
    test -e "$output"
done
