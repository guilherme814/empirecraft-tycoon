#!/usr/bin/env bash
# Prepara um ambiente Linux (Codespaces/WSL/VM) para desenvolver o jogo.
set -euo pipefail
VER=4.2.1
DIR="$HOME/.local/godot"
mkdir -p "$DIR" "$HOME/.local/bin"
if ! command -v godot >/dev/null; then
  curl -fL "https://github.com/godotengine/godot/releases/download/${VER}-stable/Godot_v${VER}-stable_linux.x86_64.zip" -o /tmp/godot.zip
  unzip -oq /tmp/godot.zip -d "$DIR"
  ln -sf "$DIR/Godot_v${VER}-stable_linux.x86_64" "$HOME/.local/bin/godot"
fi
pip install --break-system-packages numpy 2>/dev/null || pip install numpy
echo "Pronto. Rode: scripts/check.sh   (garanta ~/.local/bin no PATH)"
