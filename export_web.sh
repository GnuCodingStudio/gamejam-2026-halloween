#!/usr/bin/env bash
set -euo pipefail

GODOT="${GODOT:-Godot}"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
RELEASE_DIR="$PROJECT_DIR/.release"
VERSION="${1:-0.0.0}"
ZIP_PATH="$PROJECT_DIR/TheWholeAdventure-$VERSION.zip"

rm -rf "$RELEASE_DIR" "$ZIP_PATH"
mkdir -p "$RELEASE_DIR"

"$GODOT" --headless --path "$PROJECT_DIR" --export-release "Web" "$RELEASE_DIR/index.html"

(cd "$RELEASE_DIR" && zip -r "$ZIP_PATH" .)

echo "Web build zipped to $ZIP_PATH"
