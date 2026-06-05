#!/bin/zsh
# Convenience launcher for HOLLOW horror demo
# - Cleans .godot cache after edits (prevents stale resources)
# - Uses the Godot 4 binary known on this machine
# - Always starts clean (no persistent saves for the demo experience)
#
# You can run this script from ANY directory:
#   /Users/spencereese/projects/hollow/launch_hollow.sh
#   or (if your cwd is ~/projects):
#   cd hollow && ./launch_hollow.sh
#   or (if inside another project like timmy-time):
#   ../hollow/launch_hollow.sh
#
# The script automatically cds to its own folder.

set -e

cd "$(dirname "$0")"

echo "=== HOLLOW launcher ==="
echo "Location: $(pwd)"

# For normal play, we do NOT delete .godot (keeps Godot's resource cache for faster startup).
# If you are actively editing scripts/scenes and seeing stale errors, run with CLEAN=1:
#   CLEAN=1 ./launch_hollow.sh
if [[ "${CLEAN:-0}" == "1" ]]; then
  echo "CLEAN=1 detected: removing .godot cache..."
  rm -rf .godot
else
  echo "(Using existing .godot cache for faster startup. Set CLEAN=1 to force a full reimport.)"
fi

# Always start the game state fresh (no carry-over progress) for the intended horror experience.
# Comment the next block if you want to keep play data between runs.
echo "Preparing clean demo start (removing previous play data)..."
rm -rf "$HOME/Library/Application Support/Godot/app_userdata/HOLLOW" 2>/dev/null || true

GODOT_BIN="/Users/spencereese/Downloads/Godot.app/Contents/MacOS/Godot"

if [[ ! -x "$GODOT_BIN" ]]; then
  echo "ERROR: Godot binary not found at $GODOT_BIN"
  echo ""
  echo "You can still run the demo by:"
  echo "  1. Open /Applications (or your Godot location)"
  echo "  2. Drag the 'hollow' folder onto the Godot app icon, or"
  echo "  3. In Godot: Project -> Open Project -> select the hollow folder"
  echo ""
  echo "Or edit GODOT_BIN in this script to point to your Godot binary."
  exit 1
fi

echo "Launching HOLLOW..."
echo "Controls: WASD move, Mouse look (CLICK or MOVE MOUSE in the 3D window to capture - needed on macOS), E interact, F flashlight, Shift sprint, Tab/J journal, Esc pause/menu."
echo ""

exec "$GODOT_BIN" --path . "$@"