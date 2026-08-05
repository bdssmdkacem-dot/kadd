#!/usr/bin/env bash
# Mirrors .github/workflows/build-apk.yml, for building locally without
# waiting on GitHub Actions. Run from the repo root.
set -euo pipefail

echo "==> Generating android/ platform folder"
flutter create --platforms=android --org com.comptaflow .

echo "==> Copying native Kotlin sources"
mkdir -p android/app/src/main/kotlin/com/comptaflow/kadd
cp android_additions/kotlin/*.kt android/app/src/main/kotlin/com/comptaflow/kadd/

echo "==> Patching AndroidManifest.xml"
python3 scripts/patch_manifest.py

echo "==> flutter pub get"
flutter pub get

echo "==> Generating launcher icons"
flutter pub run flutter_launcher_icons

echo "==> Building debug APK (use --release for a release build)"
if [[ "${1:-}" == "--release" ]]; then
  flutter build apk --release
  echo "APK at build/app/outputs/flutter-apk/app-release.apk"
else
  flutter build apk --debug
  echo "APK at build/app/outputs/flutter-apk/app-debug.apk"
fi
