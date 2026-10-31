#!/usr/bin/env bash
# AquaVoice: prepara o ambiente e roda o app no Simulador do iPhone
# (ou num Android conectado: ./rodar_simulador.command android).
#
# Enquanto estiver rodando, qualquer alteração em mobile/lib é aplicada
# automaticamente no app (hot reload). Teclas: r = reload, R = restart, q = sair.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/mobile"
TARGET="${1:-ios}"
FLUTTER_HOME="$HOME/development/flutter"

say() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
fail() { printf '\n\033[1;31m✗ %s\033[0m\n' "$*"; read -r -p "Pressione Enter para fechar..."; exit 1; }

# ------------------------------------------------------------ Flutter
export PATH="$FLUTTER_HOME/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
if ! command -v flutter >/dev/null 2>&1; then
  say "Flutter não encontrado. Instalando em $FLUTTER_HOME (só na primeira vez, ~5 min)..."
  mkdir -p "$HOME/development"
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$FLUTTER_HOME" || fail "Falha ao baixar o Flutter."
  # Deixa o flutter disponível também em novos terminais
  if ! grep -q 'development/flutter/bin' "$HOME/.zshrc" 2>/dev/null; then
    echo 'export PATH="$HOME/development/flutter/bin:$PATH"' >> "$HOME/.zshrc"
  fi
fi
flutter --version | head -1

# ------------------------------------------------------------ iOS
if [ "$TARGET" = "ios" ]; then
  xcode-select -p 2>/dev/null | grep -q Xcode.app \
    || fail "Instale o Xcode pela App Store, abra-o uma vez e rode: sudo xcode-select -s /Applications/Xcode.app"
  xcrun simctl list runtimes 2>/dev/null | grep -q iOS \
    || fail "Nenhum simulador iOS instalado. Abra o Xcode > Settings > Components e baixe a plataforma iOS."
  # Plugins nativos do iOS: Swift Package Manager (+ CocoaPods como reserva)
  flutter config --enable-swift-package-manager >/dev/null 2>&1 || true
  if ! command -v pod >/dev/null 2>&1 && command -v brew >/dev/null 2>&1; then
    say "Instalando CocoaPods..."
    brew install cocoapods || true
  fi

  say "Abrindo o Simulador..."
  DEVICE_ID=$(xcrun simctl list devices booted | grep -Eo '\(([0-9A-F-]{36})\)' | head -1 | tr -d '()')
  if [ -z "$DEVICE_ID" ]; then
    DEVICE_ID=$(xcrun simctl list devices available | grep -E 'iPhone' | grep -Eo '\(([0-9A-F-]{36})\)' | tail -1 | tr -d '()')
    [ -n "$DEVICE_ID" ] || fail "Nenhum iPhone disponível no simulador."
    xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
  fi
  open -a Simulator
  DEVICE_ARG=(-d "$DEVICE_ID")
else
  say "Procurando Android conectado (ative a Depuração USB)..."
  DEVICE_ARG=(-d android)
fi

# ------------------------------------------------------------ Projeto
cd "$APP" || fail "Pasta mobile/ não encontrada."
if [ ! -d ios/Runner.xcodeproj ] || [ ! -d android/app/src/main/kotlin ]; then
  say "Primeira execução: preparando o projeto..."
  bash tool/setup_platforms.sh || fail "Falha ao preparar o projeto."
else
  flutter pub get >/dev/null || fail "Falha no flutter pub get."
fi

# ------------------------------------------------------------ Hot reload automático
PIDFILE="$(mktemp -t aquavoice).pid"
rm -f "$PIDFILE"
(
  last=""
  while sleep 2; do
    [ -f "$PIDFILE" ] || continue
    sig=$(find lib -name '*.dart' -exec stat -f '%m %N' {} + 2>/dev/null | sort | md5 -q)
    if [ -n "$last" ] && [ "$sig" != "$last" ]; then
      kill -USR1 "$(cat "$PIDFILE")" 2>/dev/null && printf '\n\033[1;32m↻ Alteração detectada: hot reload\033[0m\n'
    fi
    last="$sig"
  done
) &
WATCHER=$!
trap 'kill $WATCHER 2>/dev/null; rm -f "$PIDFILE"' EXIT

say "Iniciando o AquaVoice (a primeira compilação demora alguns minutos)..."
flutter run "${DEVICE_ARG[@]}" --pid-file "$PIDFILE"
