#!/usr/bin/env bash
# Build Kadd from the same generated Android project used by GitHub Actions.
set -euo pipefail

echo "==> Removing generated android/ folder"
rm -rf android

echo "==> Generating Android platform"
flutter create --platforms=android --org com.comptaflow .

echo "==> Copying canonical native Kotlin sources"
mkdir -p android/app/src/main/kotlin/com/comptaflow/kadd
cp android_additions/kotlin/*.kt android/app/src/main/kotlin/com/comptaflow/kadd/

echo "==> Patching generated Android project"
python3 scripts/patch_manifest.py

echo "==> Installing Flutter dependencies"
flutter pub get

echo "==> Generating launcher icons"
flutter pub run flutter_launcher_icons

echo "==> Building APK"
if [[ "${1:-}" == "--release" ]]; then
  flutter build apk --release
  echo "APK at build/app/outputs/flutter-apk/app-release.apk"
else
  flutter build apk --debug
  echo "APK at build/app/outputs/flutter-apk/app-debug.apk"
fi
