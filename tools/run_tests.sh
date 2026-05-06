#!/usr/bin/env bash
# Headless GUT-Test-Runner für DinoRogue.
#
# Nutzung:
#   ./tools/run_tests.sh              # alle Unit-Tests in tests/unit
#   ./tools/run_tests.sh tests/unit/test_event_bus.gd
#
# Voraussetzungen:
#   - godot oder godot4 im PATH (4.3+ empfohlen)
#   - GUT-Addon unter addons/gut/ (im Repo)

set -euo pipefail

# Projekt-Wurzel ist Parent-Verzeichnis dieses Skripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Godot-Binary suchen
if command -v godot4 >/dev/null 2>&1; then
    GODOT_BIN="godot4"
elif command -v godot >/dev/null 2>&1; then
    GODOT_BIN="godot"
elif [[ -n "${GODOT:-}" ]]; then
    GODOT_BIN="$GODOT"
else
    echo "Fehler: weder 'godot' noch 'godot4' im PATH gefunden."
    echo "Setze die Umgebungsvariable GODOT, oder installiere Godot 4.3+."
    exit 127
fi

echo "Godot: $($GODOT_BIN --version 2>&1 | head -1)"
echo "Projekt: $PROJECT_ROOT"
echo ""

# Eingabe-Verzeichnis oder einzelnes Test-File
TARGET="${1:-res://tests/unit}"
if [[ "$TARGET" != res://* ]]; then
    # relative Pfade in res:// umwandeln
    TARGET="res://${TARGET#./}"
fi

# Wenn Verzeichnis-artig: -gdir, sonst -gtest
if [[ "$TARGET" == *.gd ]]; then
    GUT_ARGS="-gtest=$TARGET"
else
    GUT_ARGS="-gdir=$TARGET"
fi

echo "GUT-Args: $GUT_ARGS"
echo ""

"$GODOT_BIN" --headless --path . \
    -s addons/gut/gut_cmdln.gd \
    "$GUT_ARGS" \
    -gexit \
    -glog=2

EXIT_CODE=$?
echo ""
echo "GUT exit code: $EXIT_CODE"
exit $EXIT_CODE
