#!/usr/bin/env bash
# Mesmas verificações do CI: import (2 passes), testes, smoke de UI.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
command -v "$GODOT" >/dev/null || { echo "Godot não encontrado (defina GODOT=/caminho)"; exit 1; }
"$GODOT" --headless --editor --quit-after 300 >/dev/null 2>&1 || true
OUT=$("$GODOT" --headless --editor --quit 2>&1 || true)
if echo "$OUT" | grep -E "SCRIPT ERROR|Parse Error"; then echo "FALHA: erros de script"; exit 1; fi
"$GODOT" --headless --script tests/run_tests.gd 2>&1 | tee /tmp/ec_tests.log | tail -5
grep -q "ALL TESTS PASSED" /tmp/ec_tests.log
"$GODOT" --headless res://tests/UISmoke.tscn 2>&1 | tail -3
echo "OK"
