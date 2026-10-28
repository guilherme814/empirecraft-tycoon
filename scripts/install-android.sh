#!/usr/bin/env bash
# Baixa o APK mais recente (GitHub Releases) e abre o instalador. Funciona no Termux.
set -euo pipefail
REPO=guilherme814/empirecraft-tycoon
URL="https://github.com/$REPO/releases/download/latest-build/EmpireCraft.apk"
OUT="${HOME}/storage/downloads/EmpireCraft.apk"
[ -d "$HOME/storage/downloads" ] || OUT="$HOME/EmpireCraft.apk"
curl -fL "$URL" -o "$OUT"
echo "Baixado em $OUT"
if command -v termux-open >/dev/null; then termux-open "$OUT"; else echo "Abra o arquivo para instalar (permita fontes desconhecidas)."; fi
