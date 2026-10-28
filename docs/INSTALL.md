# Instalação

## Jogar no celular (Android)
1. No GitHub: **Releases → Build mais recente** → baixe `EmpireCraft.apk`.
2. Abra o arquivo e permita "instalar apps desconhecidos". (APK de debug, arm64.)
3. No Termux: `bash scripts/install-android.sh`.

## Desenvolver
- Codespaces: abra o repositório (o `.devcontainer` instala Godot 4.2.1).
- Linux/WSL: `bash scripts/setup-dev.sh` e depois `bash scripts/check.sh`.
- Termux: edite o código e dê push; o GitHub Actions testa e gera o APK.
