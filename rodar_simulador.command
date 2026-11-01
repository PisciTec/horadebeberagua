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
LOG="$ROOT/.aquavoice-run.log"

# Toda a saída também vai para o log (ajuda a diagnosticar problemas)
: > "$LOG"
exec 3>&1 4>&2                    # guarda o terminal original
exec > >(tee -a "$LOG") 2>&1

say()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m✓ %s\033[0m\n' "$*"; }
fail() {
  printf '\n\033[1;31m✗ %s\033[0m\n' "$*"
  printf '\nO log completo está em: %s\n' "$LOG"
  read -r -p "Pressione Enter para fechar..." _
  exit 1
}

echo "AquaVoice - $(date)"
echo "macOS $(sw_vers -productVersion 2>/dev/null) ($(uname -m))"

# ------------------------------------------------------------ Xcode
if [ "$TARGET" = "ios" ]; then
  say "Verificando o Xcode..."
  XCODE_APP=""
  for c in /Applications/Xcode.app /Applications/Xcode-beta.app; do
    [ -d "$c" ] && XCODE_APP="$c" && break
  done
  [ -n "$XCODE_APP" ] || fail "Xcode não encontrado. Instale pela App Store, abra uma vez e rode este script de novo."
  # Usa o Xcode mesmo que o sistema aponte para as Command Line Tools (evita precisar de sudo)
  export DEVELOPER_DIR="$XCODE_APP/Contents/Developer"
  ok "$("$DEVELOPER_DIR/usr/bin/xcodebuild" -version 2>/dev/null | head -1) em $XCODE_APP"
  if ! "$DEVELOPER_DIR/usr/bin/xcodebuild" -checkFirstLaunchStatus >/dev/null 2>&1; then
    fail "O Xcode ainda não terminou a configuração inicial.
   Abra o Xcode, aceite a licença e deixe instalar os componentes. Depois rode este script de novo."
  fi
  xcrun simctl list runtimes 2>/dev/null | grep -q "iOS" \
    || fail "Nenhum simulador de iPhone instalado.
   No Xcode: menu Xcode > Settings > Components (ou Platforms) > baixe 'iOS'."
  ok "Simulador iOS disponível"
fi

# ------------------------------------------------------------ Git
command -v git >/dev/null 2>&1 || fail "git não encontrado. Rode no Terminal: xcode-select --install"

# ------------------------------------------------------------ Flutter
say "Verificando o Flutter..."
export PATH="$FLUTTER_HOME/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
if ! command -v flutter >/dev/null 2>&1; then
  say "Flutter não encontrado. Instalando em $FLUTTER_HOME (só na primeira vez, ~5 min)..."
  mkdir -p "$HOME/development"
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$FLUTTER_HOME" \
    || fail "Falha ao baixar o Flutter (verifique a internet)."
  # Deixa o flutter disponível em novos terminais e no VS Code
  for rc in "$HOME/.zshrc" "$HOME/.bash_profile"; do
    grep -q 'development/flutter/bin' "$rc" 2>/dev/null \
      || echo 'export PATH="$HOME/development/flutter/bin:$PATH"' >> "$rc"
  done
fi
flutter --disable-analytics >/dev/null 2>&1 || true
flutter --version 2>&1 | head -1 || fail "O Flutter não executou."
ok "Flutter em $(dirname "$(dirname "$(command -v flutter)")")"

if [ "$TARGET" = "ios" ]; then
  # Plugins nativos do iOS: Swift Package Manager (CocoaPods como reserva)
  flutter config --enable-swift-package-manager >/dev/null 2>&1 || true
  if ! command -v pod >/dev/null 2>&1; then
    if command -v brew >/dev/null 2>&1; then
      say "Instalando CocoaPods (reserva para plugins sem Swift Package Manager)..."
      brew install cocoapods || echo "Aviso: CocoaPods não instalado; seguindo com Swift Package Manager."
    else
      echo "Aviso: CocoaPods/Homebrew ausentes; seguindo com Swift Package Manager."
    fi
  fi
fi

# ------------------------------------------------------------ Projeto
cd "$APP" || fail "Pasta mobile/ não encontrada."
say "Preparando o projeto..."
bash tool/setup_platforms.sh || fail "Falha ao preparar o projeto (veja as mensagens acima)."

# ------------------------------------------------------------ Dispositivo
if [ "$TARGET" = "ios" ]; then
  say "Abrindo o Simulador do iPhone..."
  DEVICE_ID=$(xcrun simctl list devices booted | grep -E 'iPhone' | grep -Eo '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}' | head -1)
  if [ -z "$DEVICE_ID" ]; then
    DEVICE_ID=$(xcrun simctl list devices available | grep -E '^\s+iPhone' | grep -Eo '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}' | tail -1)
    [ -n "$DEVICE_ID" ] || fail "Nenhum iPhone disponível no simulador. No Xcode: Window > Devices and Simulators > + para criar um."
    xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
  fi
  open -a Simulator --args -CurrentDeviceUDID "$DEVICE_ID"
  xcrun simctl bootstatus "$DEVICE_ID" -b >/dev/null 2>&1 || true
  ok "Simulador pronto ($DEVICE_ID)"
  DEVICE_ARG=(-d "$DEVICE_ID")
else
  say "Procurando Android conectado (ative a Depuração USB)..."
  DEVICE_ARG=(-d android)
fi

# ------------------------------------------------------------ Hot reload automático
PIDFILE="${TMPDIR:-/tmp}/aquavoice-flutter.pid"
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
echo "Teclas: r = recarregar | R = reiniciar | q = sair"
# Devolve o terminal de verdade ao flutter (teclas r/R/q) e continua gravando o log
exec 1>&3 2>&4
script -q -a "$LOG" flutter run "${DEVICE_ARG[@]}" --pid-file "$PIDFILE" \
  || fail "A compilação falhou (veja as mensagens acima)."
