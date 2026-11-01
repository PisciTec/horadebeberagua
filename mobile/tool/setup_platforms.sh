#!/usr/bin/env bash
# Gera as pastas android/ e ios/ que faltam (flutter create não sobrescreve
# arquivos existentes, como o AndroidManifest.xml customizado) e aplica os
# ajustes do AquaVoice. Pode ser executado várias vezes.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -d ios/Runner.xcodeproj ] && [ -d android/app/src/main/kotlin ] && [ "${1:-}" != "--force" ]; then
  echo "==> Plataformas já geradas."
else
  echo "==> Gerando arquivos de plataforma (android/ios)..."
  flutter create --org com.nicacio --project-name aquavoice --platforms=android,ios .
fi

# ---------------------------------------------------------------- Android
GRADLE=android/app/build.gradle.kts
if [ -f "$GRADLE" ]; then
  # Android 8.0 (API 26) como versão mínima
  perl -0pi -e 's/minSdk\s*=\s*flutter\.minSdkVersion/minSdk = 26/' "$GRADLE"
  # Desugaring exigido pelo flutter_local_notifications
  if ! grep -q "isCoreLibraryDesugaringEnabled" "$GRADLE"; then
    perl -0pi -e 's/compileOptions\s*\{/compileOptions {\n        isCoreLibraryDesugaringEnabled = true/' "$GRADLE"
  fi
  if ! grep -q "desugar_jdk_libs" "$GRADLE"; then
    printf '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n' >> "$GRADLE"
  fi
fi

# ---------------------------------------------------------------- iOS
PLIST=ios/Runner/Info.plist
PB=/usr/libexec/PlistBuddy
if [ -f "$PLIST" ] && [ -x "$PB" ]; then
  $PB -c "Add :NSMicrophoneUsageDescription string 'O AquaVoice usa o microfone para gravar sua voz como som do alarme.'" "$PLIST" 2>/dev/null || true
  $PB -c "Add :UIBackgroundModes array" "$PLIST" 2>/dev/null || true
  $PB -c "Add :UIBackgroundModes:0 string audio" "$PLIST" 2>/dev/null || true
  $PB -c "Set :CFBundleDisplayName AquaVoice" "$PLIST" 2>/dev/null || true
fi
PBX=ios/Runner.xcodeproj/project.pbxproj
if [ -f "$PBX" ]; then
  # iOS 14 como versão mínima
  perl -pi -e 's/IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;/IPHONEOS_DEPLOYMENT_TARGET = 14.0;/g' "$PBX"
fi
if [ -f ios/Podfile ]; then
  perl -pi -e "s/^#?\s*platform :ios, '[0-9.]+'/platform :ios, '14.0'/" ios/Podfile
fi

echo "==> Baixando dependências..."
flutter pub get
echo "==> Plataformas prontas."
